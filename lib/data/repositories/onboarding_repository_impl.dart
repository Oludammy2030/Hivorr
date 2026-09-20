import 'package:hivorr/data/datasources/remote/onboarding_remote_data_source.dart';
import 'package:hivorr/data/entities/onboarding_status.dart';
import 'package:hivorr/data/mappers/onboarding_status_mapper.dart';
import 'package:hivorr/data/repositories/onboarding_repository.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// Default implementation composing the remote onboarding datasource.
///
/// No business decisions are made here — all errors propagate as typed
/// [ApiException]s and the DTO is mapped 1:1 to the domain entity
/// (EP-01-08 §5.6).
class OnboardingRepositoryImpl implements OnboardingRepository {
  /// Creates the repository from its datasource dependency.
  OnboardingRepositoryImpl({required this.remote});

  /// The remote (Supabase) datasource.
  final OnboardingRemoteDataSource remote;

  @override
  Future<OnboardingStatus> getStatus() async =>
      OnboardingStatusMapper.toEntity(await remote.getStatus());

  @override
  Future<OnboardingStatus> update({
    EntityCapability? capability,
    bool? completed,
  }) async => OnboardingStatusMapper.toEntity(
    await remote.updateStatus(
      capability: capability?.name,
      completed: completed,
    ),
  );
}
