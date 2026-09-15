// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/portfolio_remote_data_source.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/mappers/portfolio_mappers.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';

/// Default implementation of [PortfolioRepository] (EP-02-19).
///
/// Delegates to the [PortfolioRemoteDataSource] and maps the DTO through
/// [PortfolioMappers]. Returns `null` when the server raises `PLT004`
/// (not-found / inactive / unapproved) so the screen can render a clean
/// not-found state without leaking entity existence.
class PortfolioRepositoryImpl implements PortfolioRepository {
  PortfolioRepositoryImpl({required PortfolioRemoteDataSource remote})
      : _remote = remote;

  final PortfolioRemoteDataSource _remote;

  @override
  Future<PublicProfile?> getPublicProfile(String entityId) async {
    try {
      final dto = await _remote.fetchPublicProfile(entityId);
      return PortfolioMappers.toPublicProfile(dto);
    } on ApiException catch (e) {
      if (e.kind == ApiExceptionKind.notFound) {
        return null;
      }
      rethrow;
    }
  }
}
