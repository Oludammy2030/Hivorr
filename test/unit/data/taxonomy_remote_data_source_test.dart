import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/builders/taxonomy_builders.dart';
import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_api.dart';

void main() {
  group('SupabaseTaxonomyRemoteDataSource', () {
    test('listIndustries unwraps the envelope and maps rows, forwarding '
        'params', () async {
      Map<String, dynamic>? capturedParams;
      final SupabaseTaxonomyRemoteDataSource remote =
          SupabaseTaxonomyRemoteDataSource(
        dio: buildTestDio(StubAdapter((_) async => jsonBody(200))),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'taxonomy_industries_list': (Map<String, dynamic> params) {
              capturedParams = params;
              return <String, dynamic>{
                'success': true,
                'code': 'PLT000',
                'message': 'ok',
                'data': <Map<String, dynamic>>[
                  IndustryDtoBuilder()
                      .withId('i1')
                      .withSlug('legal')
                      .withName('Legal')
                      .toMap(),
                  IndustryDtoBuilder()
                      .withId('i2')
                      .withSlug('financial-services')
                      .withName('Financial Services')
                      .toMap(),
                ],
              };
            },
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

      final List<IndustryDto> industries = await remote.listIndustries(
        includeInactive: true,
      );

      expect(capturedParams, <String, dynamic>{'p_include_inactive': true});
      expect(industries.map((IndustryDto i) => i.slug), <String>[
        'legal',
        'financial-services',
      ]);
    });

    test('listProfessions forwards industryId (and null when scoping to '
        'all)', () async {
      final List<Map<String, dynamic>> captured = <Map<String, dynamic>>[];
      final SupabaseTaxonomyRemoteDataSource remote =
          SupabaseTaxonomyRemoteDataSource(
        dio: buildTestDio(StubAdapter((_) async => jsonBody(200))),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'taxonomy_professions_list': (Map<String, dynamic> params) {
              captured.add(params);
              return <String, dynamic>{
                'success': true,
                'code': 'PLT000',
                'message': 'ok',
                'data': <Map<String, dynamic>>[
                  ProfessionDtoBuilder()
                      .withIndustryId('i1')
                      .withSlug('lawyer')
                      .withName('Lawyer')
                      .toMap(),
                ],
              };
            },
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

      final List<ProfessionDto> scoped = await remote.listProfessions(
        industryId: 'i1',
      );
      final List<ProfessionDto> all = await remote.listProfessions();

      expect(scoped.single.slug, 'lawyer');
      expect(all.single.slug, 'lawyer');
      expect(captured[0], <String, dynamic>{
        'p_industry_id': 'i1',
        'p_include_inactive': false,
      });
      expect(captured[1], <String, dynamic>{
        'p_industry_id': null,
        'p_include_inactive': false,
      });
    });

    test('treats a success:false envelope as a server failure', () async {
      final SupabaseTaxonomyRemoteDataSource remote =
          SupabaseTaxonomyRemoteDataSource(
        dio: buildTestDio(StubAdapter((_) async => jsonBody(200))),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'taxonomy_industries_list': (_) => <String, dynamic>{
                  'success': false,
                  'code': 'PLT999',
                  'message': 'boom',
                  'data': <Map<String, dynamic>>[],
                },
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

      await expectLater(
        remote.listIndustries(),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.server)
              .having((ApiException e) => e.code, 'code', 'PLT999'),
        ),
      );
    });

    test('rejects an envelope whose data is not a list', () async {
      final SupabaseTaxonomyRemoteDataSource remote =
          SupabaseTaxonomyRemoteDataSource(
        dio: buildTestDio(StubAdapter((_) async => jsonBody(200))),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'taxonomy_industries_list': (_) => <String, dynamic>{
                  'success': true,
                  'code': 'PLT000',
                  'message': 'ok',
                  'data': <String, dynamic>{'unexpected': true},
                },
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

      await expectLater(
        remote.listIndustries(),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.unknown),
        ),
      );
    });

    test('normalizes a PostgrestException to a typed ApiException', () async {
      final SupabaseTaxonomyRemoteDataSource remote =
          SupabaseTaxonomyRemoteDataSource(
        dio: buildTestDio(StubAdapter((_) async => jsonBody(200))),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'taxonomy_industries_list': (_) =>
                throw const PostgrestException(message: 'denied', code: 'PLT001'),
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

      await expectLater(
        remote.listIndustries(),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)
              .having((ApiException e) => e.code, 'code', 'PLT001'),
        ),
      );
    });

    test('normalizes any raw thrown error to an ApiException', () async {
      final SupabaseTaxonomyRemoteDataSource remote =
          SupabaseTaxonomyRemoteDataSource(
        dio: buildTestDio(StubAdapter((_) async => jsonBody(200))),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'taxonomy_industries_list': (_) => throw Exception('transport'),
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

      await expectLater(
        remote.listIndustries(),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.unknown),
        ),
      );
    });
  });
}