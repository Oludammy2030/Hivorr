import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_portfolio_remote_data_source.dart';
import 'package:hivorr/data/models/public_credential_dto.dart';
import 'package:hivorr/data/models/public_profile_dto.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_portfolio.dart';

void main() {
  SupabasePortfolioRemoteDataSource build(
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  ) => SupabasePortfolioRemoteDataSource(
    dio: Dio(),
    supabase: MockSupabaseClientFactory.create(rpcHandlers: rpcHandlers),
    exceptionMapper: const ApiExceptionMapper(),
  );

  Map<String, dynamic> ok(Map<String, dynamic> data) => <String, dynamic>{
    'success': true,
    'code': 'PLT000',
    'message': 'ok',
    'data': data,
  };

  group('SupabasePortfolioRemoteDataSource.fetchPublicProfile', () {
    test('calls portfolio_public_profile_get with p_entity_id', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'portfolio_public_profile_get': (Map<String, dynamic> body) {
          seenFn = 'portfolio_public_profile_get';
          seenParams = body;
          return ok(seedPublicProfileDto().toJson());
        },
      });

      final PublicProfileDto dto = await source.fetchPublicProfile('entity-1');

      expect(seenFn, 'portfolio_public_profile_get');
      expect(seenParams, containsPair('p_entity_id', 'entity-1'));
      expect(dto.entityId, 'entity-1');
      expect(dto.displayName, 'Ada Lovelace');
    });

    test('returns a valid DTO from a full envelope payload', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'portfolio_public_profile_get': (_) => ok(
          seedPublicProfileDto(
            entityId: 'ent-2',
            displayName: 'Marie Curie',
            credentials: <PublicCredentialDto>[
              seedPublicCredentialDto(
                kind: 'identity_document',
                title: 'National ID',
              ),
            ],
          ).toJson(),
        ),
      });

      final PublicProfileDto dto = await source.fetchPublicProfile('ent-2');

      expect(dto.entityId, 'ent-2');
      expect(dto.displayName, 'Marie Curie');
      expect(dto.credentials, hasLength(1));
      expect(dto.credentials[0].kind, 'identity_document');
    });

    test('maps PLT004 to notFound ApiException', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'portfolio_public_profile_get': (_) => <String, dynamic>{
          'code': 'PLT004',
          'message': 'not found',
          'data': <String, dynamic>{},
        },
      });

      expect(
        () => source.fetchPublicProfile('unknown'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.notFound,
              )
              .having((ApiException e) => e.code, 'code', 'PLT004'),
        ),
      );
    });

    test('maps a non-object data payload to server ApiException', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'portfolio_public_profile_get': (_) => <String, dynamic>{
          'code': 'PLT000',
          'data': 'not-a-map',
        },
      });

      expect(
        () => source.fetchPublicProfile('entity-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });

    test(
      'maps a thrown transport error to a typed ApiException (never raw)',
      () {
        final source = build(<String, Object? Function(Map<String, dynamic>)>{
          'portfolio_public_profile_get': (_) =>
              throw StateError('network down'),
        });

        expect(
          () => source.fetchPublicProfile('entity-1'),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });
}
