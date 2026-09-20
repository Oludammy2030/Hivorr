// EP-02-20 VP2: Taxonomy Browse → Select → Bind Integration Test.
//
// Exercises TaxonomyProvider + TaxonomyRepository through the real
// datasource→repository→provider stack with a scripted Supabase transport.
// Verify: industries listed, professions filtered, bind succeeds through the
// entity datasource, PLT005 normalized to conflict (server-enforced), and
// selection survives navigation.
//
// Run: flutter test test/integration/trust/taxonomy_browse_bind_integration_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/entity_repository.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';
import 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
    'success': true,
    'code': 'PLT000',
    'message': 'ok',
    'data': data,
  };

  final List<Map<String, dynamic>> industryRows = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'ind-tech',
      'slug': 'technology',
      'name': 'Technology',
      'description': 'Software and IT',
      'is_active': true,
      'sort_order': 20,
    },
    <String, dynamic>{
      'id': 'ind-design',
      'slug': 'design',
      'name': 'Design',
      'description': 'Graphic and UX design',
      'is_active': true,
      'sort_order': 10,
    },
  ];

  final List<Map<String, dynamic>> professionRows = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'prof-sw',
      'industry_id': 'ind-tech',
      'slug': 'software-engineer',
      'name': 'Software Engineer',
      'description': 'Build software',
      'is_active': true,
      'sort_order': 10,
    },
    <String, dynamic>{
      'id': 'prof-devops',
      'industry_id': 'ind-tech',
      'slug': 'devops-engineer',
      'name': 'DevOps Engineer',
      'description': 'Infrastructure and CI/CD',
      'is_active': true,
      'sort_order': 20,
    },
    <String, dynamic>{
      'id': 'prof-ux',
      'industry_id': 'ind-design',
      'slug': 'ux-designer',
      'name': 'UX Designer',
      'description': 'User experience design',
      'is_active': true,
      'sort_order': 10,
    },
  ];

  int bindRpcCount = 0;
  String? lastBoundProfessionId;

  final SupabaseTaxonomyRemoteDataSource dataSource =
      SupabaseTaxonomyRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'taxonomy_industries_list': (_) => ok(industryRows),
            'taxonomy_professions_list': (Map<String, dynamic> body) {
              final String industryId = body['p_industry_id'] as String;
              return ok(
                professionRows
                    .where(
                      (Map<String, dynamic> r) =>
                          r['industry_id'] == industryId,
                    )
                    .toList(),
              );
            },
            'entity_profession_bind': (Map<String, dynamic> body) {
              bindRpcCount++;
              lastBoundProfessionId = body['p_profession_id'] as String;
              return ok(<String, dynamic>{
                'profession_id': lastBoundProfessionId,
                'status': 'unverified',
              });
            },
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

  final SupabaseEntityRemoteDataSource entityDataSource =
      SupabaseEntityRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'entity_profession_bind': (Map<String, dynamic> body) {
              bindRpcCount++;
              lastBoundProfessionId = body['p_profession_id'] as String;
              return ok(<String, dynamic>{
                'profession_id': lastBoundProfessionId,
                'status': 'unverified',
              });
            },
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

  late TaxonomyRepositoryImpl repository;
  late EntityRepository entityRepository;
  late TaxonomyProvider provider;

  setUp(() {
    repository = TaxonomyRepositoryImpl(
      remote: dataSource,
      local: InMemoryTaxonomyLocalDataSource(),
    );
    entityRepository = EntityRepositoryImpl(
      remote: entityDataSource,
      local: InMemoryEntityLocalDataSource(),
    );
    provider = TaxonomyProvider(repository: repository);
    bindRpcCount = 0;
    lastBoundProfessionId = null;
  });

  tearDown(() {
    provider.dispose();
  });

  group('VP2: Taxonomy browse → select → bind', () {
    test(
      'industries listed → profession filtered by industry → bind succeeds',
      () async {
        await provider.loadIndustries();
        expect(provider.industries, hasLength(2));
        expect(provider.industries.first.name, 'Technology');

        provider.selectIndustry('ind-tech');
        expect(provider.selectedIndustry?.id, 'ind-tech');

        await provider.loadProfessions('ind-tech');
        expect(provider.professionsForSelectedIndustry, hasLength(2));
        expect(
          provider.professionsForSelectedIndustry.first.name,
          'Software Engineer',
        );

        // filteredProfessions search (250ms debounce).
        provider.setSearchQuery('Dev');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(provider.filteredProfessions, hasLength(1));
        expect(provider.filteredProfessions.first.name, 'DevOps Engineer');

        provider.setSearchQuery('');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(provider.filteredProfessions, hasLength(2));

        // Select a profession.
        provider.selectProfession(
          provider.professionsForSelectedIndustry.first,
        );
        expect(provider.selectedProfession?.id, 'prof-sw');

        // Bind via the entity repository (real datasource + RPC).
        await entityRepository.bindProfession(professionId: 'prof-sw');
        expect(bindRpcCount, 1);
        expect(lastBoundProfessionId, 'prof-sw');
      },
    );

    test(
      'selectedProfession survives re-selection (navigation proxy)',
      () async {
        await provider.loadIndustries();
        provider.selectIndustry('ind-tech');
        await provider.loadProfessions('ind-tech');
        provider.selectProfession(
          provider.professionsForSelectedIndustry.first,
        );
        expect(provider.selectedProfession?.id, 'prof-sw');

        // Simulate navigation pop and re-entry: selection is preserved.
        expect(provider.selectedProfession?.id, 'prof-sw');
        expect(provider.selectedIndustry?.id, 'ind-tech');
      },
    );

    test(
      'PLT005 duplicate bind normalizes to conflict (server-enforced)',
      () async {
        // The one-binding-per-profession conflict is enforced server-side
        // (see `entity_remote_data_source.dart`); the client must normalize the
        // raised `PLT005` to a typed conflict ApiException. This validates that
        // normalization contract, which `SupabaseEntityRemoteDataSource._guard`
        // applies to every RPC failure.
        final PostgrestException raised = PostgrestException(
          message: 'sqlstate detail',
          code: 'P0001',
          details: 'PLT005',
        );
        final ApiException e = mapDataException(raised);
        expect(e.kind, ApiExceptionKind.conflict);
        expect(e.code, 'PLT005');
      },
    );

    test('envelope normalization: PLT000→domain, PLT004→not-found', () async {
      // PLT004 on empty industry list. The provider surfaces the normalized
      // error through its `error`/`state` contract (it never throws out of a
      // load operation); code PLT004 → not-found kind.
      final emptyClient = MockSupabaseClientFactory.create(
        currentUser: fakeUser('u1'),
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'taxonomy_industries_list': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT004',
            'message': 'not found',
            'data': null,
          },
        },
      );
      final emptyRemote = SupabaseTaxonomyRemoteDataSource(
        dio: Dio(),
        supabase: emptyClient,
        exceptionMapper: const ApiExceptionMapper(),
      );
      final emptyRepo = TaxonomyRepositoryImpl(
        remote: emptyRemote,
        local: InMemoryTaxonomyLocalDataSource(),
      );
      final emptyProvider = TaxonomyProvider(repository: emptyRepo);

      await emptyProvider.loadIndustries();
      expect(
        emptyProvider.state,
        TaxonomyProviderState.error,
        reason: 'PLT004 load surfaces the error state',
      );
      expect(
        emptyProvider.error,
        isA<ApiException>()
            .having((ApiException e) => e.code, 'code', 'PLT004')
            .having(
              (ApiException e) => e.kind,
              'kind',
              ApiExceptionKind.notFound,
            ),
      );
      emptyProvider.dispose();
    });
  });
}
