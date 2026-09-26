import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:hivorr/data/datasources/local/service_search_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/service_search_remote_data_source.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/mappers/service_listing_mapper.dart';
import 'package:hivorr/data/models/service_listing_dto.dart';
import 'package:hivorr/data/repositories/service_search_repository.dart';

/// Cache-first repository for ranked discovery, mirroring
/// `TaxonomyRepositoryImpl` (`lib/data/repositories/taxonomy_repository_impl.dart:17`).
///
/// Policy: `p_query null` (warm `browse`) is **cache-first** (local hit → return,
/// miss → remote → save) so a warm start issues zero RPCs. `p_query` FTS
/// queries are **network-first** to respect fresh `ts_rank`. Either path
/// preserves RPC order verbatim (no resort).
class ServiceSearchRepositoryImpl implements ServiceSearchRepository {
  ServiceSearchRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final ServiceSearchRemoteDataSource remote;
  final ServiceSearchLocalDataSource local;

  String _cacheKey({
    String? professionId,
    String? query,
    ServiceSearchFilters? filters,
    ServiceListingCursor? cursor,
    int limit = 20,
  }) {
    final String raw = <String>[
      'prof:${professionId ?? "_"}',
      'q:${query ?? ""}',
      'f:${filters == null || filters.isEmpty ? "{}" : jsonEncode(filters.toJson())}',
      'c:${cursor == null ? "_" : "${cursor.score}:${cursor.id}"}',
      'l:$limit',
    ].join('|');
    final String hash = sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
    return hash;
  }

  @override
  Future<ServiceSearchPage> search({
    String? professionId,
    String? query,
    ServiceSearchFilters? filters,
    ServiceListingCursor? cursor,
    int limit = 20,
  }) async {
    final String key = _cacheKey(
      professionId: professionId,
      query: query,
      filters: filters,
      cursor: cursor,
      limit: limit,
    );

    final bool isBrowse = query == null || query.trim().isEmpty;

    if (isBrowse) {
      final ServiceSearchPageDto? cached = await local.getPage(key);
      if (cached != null) {
        final ServiceSearchPage page = ServiceListingMapper.toPageEntity(cached);
        // Check weights_version freshness: if server version changed, invalidate
        final DateTime? cachedVersion = cached.weightsVersion;
        if (cachedVersion != null) {
          final DateTime? stored = await local.getWeightsVersion();
          if (stored != null && cachedVersion.isBefore(stored)) {
            await local.invalidate();
          } else {
            return page;
          }
        } else {
          return page;
        }
      }
    }

    final ServiceSearchPageDto dto = await remote.rankingSearch(
      professionId: professionId,
      query: query,
      filters: filters?.toJson(),
      cursor: cursor?.toJson(),
      limit: limit,
    );

    // Persist weights_version for future invalidation
    if (dto.weightsVersion != null) {
      final DateTime? existing = await local.getWeightsVersion();
      if (existing == null || dto.weightsVersion!.isAfter(existing)) {
        // New version → invalidate old pages before saving
        if (existing != null && dto.weightsVersion != existing) {
          await local.invalidate();
        }
        await local.saveWeightsVersion(dto.weightsVersion!);
      }
    }

    await local.savePage(key, dto);
    return ServiceListingMapper.toPageEntity(dto);
  }

  @override
  Future<void> invalidate() => local.invalidate();
}
