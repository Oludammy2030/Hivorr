import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/models/public_credential_dto.dart';
import 'package:hivorr/data/models/public_profession_dto.dart';
import 'package:hivorr/data/models/public_profile_dto.dart';
import 'package:hivorr/data/providers/portfolio_provider.dart';
import 'package:hivorr/data/repositories/portfolio_repository_impl.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/fake_portfolio.dart';
import '../../../support/fakes/fake_verification.dart';

void main() {
  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
    'hivorr.test',
    LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
    PiiRedactor(),
  );

  ProfessionalProfileService buildService({
    PublicProfileDto? result,
    ApiException? error,
    StorageService? storage,
    HivorrLogger? logger,
  }) {
    final FakePortfolioRemoteDataSource remote = FakePortfolioRemoteDataSource(
      result: result,
      error: error,
    );
    final PortfolioProvider provider = PortfolioProvider(
      repository: PortfolioRepositoryImpl(remote: remote),
    );
    return ProfessionalProfileService(
      provider: provider,
      storage: storage,
      seoBaseUrl: 'https://hivorr.com',
      logger: logger,
    );
  }

  group('ProfessionalProfileService.load', () {
    test('delegates to the provider and exposes the loaded profile', () async {
      final service = buildService();

      expect(service.isLoaded, isFalse);
      expect(service.profile, isNull);

      final PublicProfile? profile = await service.load('entity-1');

      expect(profile, isNotNull);
      expect(service.isLoaded, isTrue);
      expect(service.isLoading, isFalse);
      expect(service.profile!.entityId, 'entity-1');
      expect(service.profile!.displayName, 'Ada Lovelace');
      expect(service.lastError, isNull);
    });

    test(
      'returns null (not-found) when the repository surfaces PLT004',
      () async {
        final service = buildService(
          error: const ApiException(
            kind: ApiExceptionKind.notFound,
            message: 'not found',
            code: 'PLT004',
          ),
        );

        final PublicProfile? profile = await service.load('unknown');

        expect(profile, isNull);
        expect(service.isLoaded, isTrue);
        expect(service.profile, isNull);
        expect(service.verifiedIdentity, isFalse);
        expect(service.tradeVerified, isFalse);
      },
    );

    test('rethrows a normalized server ApiException', () async {
      final service = buildService(
        error: const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        ),
      );

      await expectLater(
        service.load('entity-1'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.server,
              )
              .having((ApiException e) => e.message, 'message', 'boom'),
        ),
      );
      expect(service.state, PortfolioLoadState.error);
      expect(service.lastError, isNotNull);
    });
  });

  group('ProfessionalProfileService trust signals', () {
    test(
      'verifiedIdentity via approved identity-document credential',
      () async {
        final service = buildService(
          result: seedPublicProfileDto(
            kycTierCode: null,
            kycStatus: null,
            credentials: <PublicCredentialDto>[
              seedPublicCredentialDto(
                kind: 'identity_document',
                verificationStatus: 'approved',
              ),
            ],
          ),
        );
        await service.load('entity-1');

        expect(service.verifiedIdentity, isTrue);
      },
    );

    test(
      'verifiedIdentity false when no identity credential and no KYC tier',
      () async {
        final service = buildService(
          result: seedPublicProfileDto(
            kycTierCode: null,
            kycStatus: null,
            credentials: <PublicCredentialDto>[
              seedPublicCredentialDto(
                kind: 'certification',
                title: 'AWS Certified',
                verificationStatus: 'approved',
              ),
            ],
          ),
        );
        await service.load('entity-1');

        expect(service.verifiedIdentity, isFalse);
      },
    );

    test(
      'verifiedIdentity true via active KYC tier_1 without credentials',
      () async {
        final service = buildService(
          result: seedPublicProfileDto(
            credentials: <PublicCredentialDto>[],
            kycTierCode: 'tier_1',
            kycStatus: 'active',
          ),
        );
        await service.load('entity-1');

        expect(service.verifiedIdentity, isTrue);
        expect(service.kycTierCode, 'tier_1');
        expect(service.kycStatus, 'active');
      },
    );

    test('verifiedIdentity false when KYC is tier_1 but not active', () async {
      final service = buildService(
        result: seedPublicProfileDto(
          credentials: <PublicCredentialDto>[],
          kycTierCode: 'tier_1',
          kycStatus: 'pending',
        ),
      );
      await service.load('entity-1');

      expect(service.verifiedIdentity, isFalse);
    });

    test('verifiedIdentity false before any load', () async {
      final service = buildService();

      expect(service.verifiedIdentity, isFalse);
    });

    test('tradeVerified true when the profile carries professions', () async {
      final service = buildService();
      await service.load('entity-1');

      expect(service.tradeVerified, isTrue);
    });

    test('tradeVerified false when the profile has no professions', () async {
      final service = buildService(
        result: seedPublicProfileDto(professions: <PublicProfessionDto>[]),
      );
      await service.load('entity-1');

      expect(service.tradeVerified, isFalse);
    });

    test('verifiedCredentialCount reflects the payload', () async {
      final service = buildService(
        result: seedPublicProfileDto(
          credentials: <PublicCredentialDto>[
            seedPublicCredentialDto(kind: 'identity_document'),
            seedPublicCredentialDto(kind: 'certification'),
          ],
        ),
      );
      await service.load('entity-1');

      expect(service.verifiedCredentialCount, 2);
      expect(service.credentials, hasLength(2));
    });
  });

  group('ProfessionalProfileService.primaryProfession', () {
    test('returns the is_primary profession when present', () async {
      final service = buildService(
        result: seedPublicProfileDto(
          professions: <PublicProfessionDto>[
            seedPublicProfessionDto(
              id: 'ep-secondary',
              professionId: 'p-2',
              isPrimary: false,
              professionName: 'Electrician',
              professionSlug: 'electrician',
            ),
            seedPublicProfessionDto(
              id: 'ep-primary',
              professionId: 'p-1',
              isPrimary: true,
              professionName: 'Software Engineer',
              professionSlug: 'software-engineer',
            ),
          ],
        ),
      );
      await service.load('entity-1');

      expect(service.primaryProfession!.id, 'ep-primary');
      expect(service.primaryProfessionName, 'Software Engineer');
      expect(service.primaryProfessionSlug, 'software-engineer');
      expect(service.primaryIndustryName, 'Technology');
    });

    test('falls back to the first profession when none is primary', () async {
      final service = buildService(
        result: seedPublicProfileDto(
          professions: <PublicProfessionDto>[
            seedPublicProfessionDto(
              id: 'ep-1',
              isPrimary: false,
              professionName: 'Plumber',
              professionSlug: 'plumber',
            ),
          ],
        ),
      );
      await service.load('entity-1');

      expect(service.primaryProfession!.id, 'ep-1');
      expect(service.primaryProfessionName, 'Plumber');
    });

    test('is null before a load', () async {
      final service = buildService();

      expect(service.primaryProfession, isNull);
      expect(service.primaryProfessionName, isNull);
    });
  });

  group('ProfessionalProfileService.seoMeta', () {
    test('is null before a successful load', () {
      final service = buildService();

      expect(service.seoMeta(routeSlug: 'software-engineer'), isNull);
    });

    test('derives title/description/canonical from payload + origin', () async {
      final service = buildService(
        result: seedPublicProfileDto(
          displayName: 'Ada Lovelace',
          bio: 'Analytical engine pioneer.',
        ),
      );
      await service.load('entity-1');

      final meta = service.seoMeta(routeSlug: 'software-engineer');

      expect(meta, isNotNull);
      expect(meta!.title, 'Ada Lovelace · Software Engineer');
      expect(meta.description, 'Analytical engine pioneer.');
      expect(
        meta.canonicalUrl,
        'https://hivorr.com/p/software-engineer/entity-1',
      );
    });

    test('payload profession slug wins over the cosmetic route slug', () async {
      final service = buildService();
      await service.load('entity-1');

      final meta = service.seoMeta(routeSlug: 'different-slug');

      expect(
        meta!.canonicalUrl,
        'https://hivorr.com/p/software-engineer/entity-1',
      );
    });

    test(
      'falls back to the route slug when the payload has no profession slug',
      () async {
        final service = buildService(
          result: seedPublicProfileDto(
            professions: <PublicProfessionDto>[],
            professionSlug: null,
            professionName: null,
            industrySlug: null,
            industryName: null,
          ),
        );
        await service.load('entity-1');

        final meta = service.seoMeta(routeSlug: 'fallback-slug');

        expect(
          meta!.canonicalUrl,
          'https://hivorr.com/p/fallback-slug/entity-1',
        );
        expect(meta.title, 'Ada Lovelace');
      },
    );
  });

  group('ProfessionalProfileService storage URLs', () {
    test('avatarPublicUrl resolves over the profile-avatars bucket', () async {
      final service = buildService(
        storage: FakeStorageService(),
        result: seedPublicProfileDto(avatarPath: 'avatars/entity-1.png'),
      );

      expect(
        service.avatarPublicUrl('avatars/entity-1.png'),
        'https://example/profile-avatars/avatars/entity-1.png',
      );
    });

    test('avatarPublicUrl is null when the path is absent or empty', () async {
      final service = buildService(storage: FakeStorageService());

      expect(service.avatarPublicUrl(null), isNull);
      expect(service.avatarPublicUrl(''), isNull);
    });

    test('avatarPublicUrl is null without a storage service', () async {
      final service = buildService();

      expect(service.avatarPublicUrl('avatars/entity-1.png'), isNull);
    });

    test('mediaPublicUrl resolves over the portfolio-items bucket', () async {
      final service = buildService(storage: FakeStorageService());

      expect(
        service.mediaPublicUrl('portfolio-items/entity-1/work.jpg'),
        'https://example/portfolio-items/portfolio-items/entity-1/work.jpg',
      );
    });

    test('mediaPublicUrl is null when the path is empty', () async {
      final service = buildService(storage: FakeStorageService());

      expect(service.mediaPublicUrl(''), isNull);
    });
  });

  group('ProfessionalProfileService logging (SV-08/PII)', () {
    test('logs the loaded profile with redacted context and no PII', () async {
      final RecordingSink sink = RecordingSink();
      final service = buildService(
        logger: makeLogger(sink),
        result: seedPublicProfileDto(
          displayName: 'Ada Lovelace',
          bio: 'Analytical engine pioneer.',
        ),
      );

      await service.load('entity-1');

      final List<LogEntry> started = sink.entries
          .where((LogEntry e) => e.message == 'Public profile load started')
          .toList();
      final List<LogEntry> completed = sink.entries
          .where((LogEntry e) => e.message == 'Public profile load completed')
          .toList();

      expect(started, hasLength(1));
      expect(started[0].context['entityIdSuffix'], 'entity-1');
      expect(completed, hasLength(1));
      expect(completed[0].context['found'], isTrue);
      expect(completed[0].context['professions'], 1);
      expect(completed[0].context['credentials'], 2);
      expect(completed[0].context['portfolioItems'], 2);

      for (final LogEntry entry in sink.entries) {
        final String dump =
            entry.message +
            entry.context.values
                .map((Object? value) => value.toString())
                .join(' ');
        expect(
          dump,
          isNot(contains('Ada')),
          reason: 'displayName must never reach the log output',
        );
        expect(
          dump,
          isNot(contains('Analytical engine pioneer')),
          reason: 'bio must never reach the log output',
        );
      }
    });

    test('logs the failure path with redacted context', () async {
      final RecordingSink sink = RecordingSink();
      final service = buildService(
        logger: makeLogger(sink),
        error: const ApiException(
          kind: ApiExceptionKind.network,
          message: 'offline',
          code: 'PLT005',
        ),
      );

      await expectLater(service.load('entity-1'), throwsA(isA<ApiException>()));

      final List<LogEntry> failed = sink.entries
          .where((LogEntry e) => e.message == 'Public profile load failed')
          .toList();

      expect(failed, hasLength(1));
      expect(failed[0].context['entityIdSuffix'], 'entity-1');
      expect(failed[0].error, isA<ApiException>());
    });
  });
}
