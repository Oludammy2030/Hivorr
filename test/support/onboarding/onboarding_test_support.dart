import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';
import 'package:hivorr/systems/onboarding/models/picked_avatar.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:hivorr/systems/verification/services/identity_verification_service.dart';
import 'package:hivorr/systems/verification/services/trade_verification_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../fakes/fake_datasource.dart';
import '../fakes/fake_storage.dart';
import '../fakes/fake_taxonomy.dart';
import '../fakes/fake_trade_verification.dart';
import '../fakes/fake_verification.dart';

/// A fully wired, faked EP-02-18 onboarding stack (plan §5.4 composition).
///
/// Mirrors `registerOnboardingLayer` with fake collaborators so unit, widget
/// and integration tests exercise the real seam — no live backend.
class OnboardingTestStack {
  const OnboardingTestStack({
    required this.remote,
    required this.local,
    required this.entityProvider,
    required this.taxonomy,
    required this.identityRepo,
    required this.identityVerification,
    required this.tradeRepo,
    required this.tradeVerification,
    required this.storage,
    required this.store,
    required this.service,
    required this.provider,
  });

  final FakeEntityRemoteDataSource remote;
  final FakeEntityLocalDataSource local;
  final EntityProvider entityProvider;
  final TaxonomyProvider taxonomy;
  final FakeVerificationRepository identityRepo;
  final IdentityVerificationService identityVerification;
  final FakeTradeVerificationRepository tradeRepo;
  final TradeVerificationService tradeVerification;
  final FakeStorageService storage;
  final InMemoryOnboardingProgressStore store;
  final OnboardingService service;
  final OnboardingProvider provider;

  /// Hydrates/resumes the wizard for [entityId].
  Future<void> hydrate(String entityId) => provider.loadProgress(entityId);

  /// The [Provider] list used by widget tests.
  List<SingleChildWidget> buildProviders() => <SingleChildWidget>[
        ChangeNotifierProvider<OnboardingProvider>.value(value: provider),
        ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy),
        ChangeNotifierProvider<EntityProvider>.value(value: entityProvider),
      ];
}

/// Builds the fake onboarding stack with in-memory collaborators.
OnboardingTestStack buildOnboardingStack({
  InMemoryOnboardingProgressStore? store,
  FakeEntityRemoteDataSource? remote,
  FakeVerificationRepository? identityRepo,
  FakeTradeVerificationRepository? tradeRepo,
  FakeTaxonomyRepository? taxonomyRepo,
  FakeStorageService? storage,
  HivorrLogger? logger,
  String entityId = 'u1',
}) {
  final FakeEntityRemoteDataSource r = remote ?? FakeEntityRemoteDataSource();
  final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
  final EntityRepositoryImpl entityRepository =
      EntityRepositoryImpl(remote: r, local: local);
  final EntityProvider entityProvider =
      EntityProvider(repository: entityRepository);
  final FakeTaxonomyRepository taxonomyRepository =
      taxonomyRepo ?? seedTaxonomyRepository();
  final TaxonomyProvider taxonomy =
      TaxonomyProvider(repository: taxonomyRepository);
  final FakeVerificationRepository identity =
      identityRepo ?? FakeVerificationRepository();
  final FakeTradeVerificationRepository trade =
      tradeRepo ?? FakeTradeVerificationRepository();
  final FakeStorageService storageService =
      storage ?? FakeStorageService();
  final InMemoryOnboardingProgressStore progressStore =
      store ?? InMemoryOnboardingProgressStore();
  final OnboardingService service = OnboardingService(
    store: progressStore,
    entityRepository: entityRepository,
    taxonomy: taxonomy,
    identityVerification: IdentityVerificationService(repo: identity),
    tradeVerification: TradeVerificationService(repo: trade),
    storage: storageService,
    logger: logger,
  );
  final OnboardingProvider provider =
      OnboardingProvider(service: service, logger: logger);
  return OnboardingTestStack(
    remote: r,
    local: local,
    entityProvider: entityProvider,
    taxonomy: taxonomy,
    identityRepo: identity,
    identityVerification: IdentityVerificationService(repo: identity),
    tradeRepo: trade,
    tradeVerification: TradeVerificationService(repo: trade),
    storage: storageService,
    store: progressStore,
    service: service,
    provider: provider,
  );
}

/// Default seed: one industry (Technology) with one active profession.
FakeTaxonomyRepository seedTaxonomyRepository() => FakeTaxonomyRepository(
      industries: <Industry>[seedIndustry()],
      professionsByIndustry: <String, List<Profession>>{
        seedIndustry().id: <Profession>[seedProfession()],
      },
    );

/// The canonical test industry.
Industry seedIndustry() => const Industry(
      id: 'ind-tech',
      slug: 'technology',
      name: 'Technology',
      description: 'Software and IT',
      isActive: true,
      sortOrder: 20,
    );

/// The canonical test profession (bound to [seedIndustry]).
Profession seedProfession() => const Profession(
      id: 'prof-sw',
      industryId: 'ind-tech',
      slug: 'software-engineer',
      name: 'Software Engineer',
      description: 'Build software',
      isActive: true,
      sortOrder: 10,
    );

/// Selects the canonical industry + profession in [taxonomy].
Future<void> selectTechnologyProfession(TaxonomyProvider taxonomy) async {
  await taxonomy.loadIndustries();
  await taxonomy.loadProfessions(seedIndustry().id);
  taxonomy.selectIndustry(seedIndustry().id);
  taxonomy.selectProfession(seedProfession());
}

/// A valid, decodable 1x1 transparent PNG so `MemoryImage` previews never fail
/// image decoding in widget tests.
Uint8List seedPngBytes() => Uint8List.fromList(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0xFC, 0xCF, 0xC0, 0x50,
      0x0F, 0x00, 0x05, 0x05, 0x02, 0x01, 0x24, 0x12, 0x75, 0x1E, 0x00, 0x00,
      0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

/// A small valid identity/trade document.
PickedDocument seedPickedFile() => PickedDocument(
      bytes: seedPngBytes(),
      fileName: 'document.png',
      mimeType: 'image/png',
    );

/// A small valid avatar image.
PickedAvatar seedPickedAvatar() => PickedAvatar(
      bytes: seedPngBytes(),
      fileName: 'me.png',
      mimeType: 'image/png',
    );

/// Marker screen used by the onboarding test router so navigation assertions
/// can target a stable label instead of the destination UI.
class OnboardingMarkerScreen extends StatelessWidget {
  const OnboardingMarkerScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

/// Builds a GoRouter with the onboarding navigation surface so screens that
/// invoke `goNamed`/`go`/`push` settle without a real router.
GoRouter onboardingTestRouter({
  required String path,
  required Widget child,
  List<RouteBase> routes = const <RouteBase>[],
}) {
  return GoRouter(
    initialLocation: path,
    routes: <RouteBase>[
      GoRoute(
        path: path,
        name: _nameFor(path),
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: child),
      ),
      for (final (String name, String label) in _markers)
        if (name != _nameFor(path)) _marker(name, label),
      ...routes,
    ],
  );
}

const List<(String, String)> _markers = <(String, String)>[
  (RouteNames.onboardingCapability, 'ONBOARDING-CAPABILITY'),
  (RouteNames.onboardingProfile, 'ONBOARDING-PROFILE'),
  (RouteNames.onboardingIndustry, 'ONBOARDING-INDUSTRY'),
  (RouteNames.onboardingIdentity, 'ONBOARDING-IDENTITY'),
  (RouteNames.onboardingTradeProof, 'ONBOARDING-TRADE-PROOF'),
  (RouteNames.onboardingComplete, 'ONBOARDING-COMPLETE'),
  (RouteNames.home, 'HOME'),
  (RouteNames.verificationStatus, 'VERIFICATION-STATUS'),
];

/// Pumps [child] at [path] inside a GoRouter-backed [MaterialApp] with the
/// onboarding providers injected.
Future<void> pumpOnboardingScreen(
  WidgetTester tester,
  Widget child, {
  required String path,
  List<SingleChildWidget>? providers,
  bool dark = false,
}) async {
  final GoRouter router = onboardingTestRouter(path: path, child: child);
  final Widget app = MaterialApp.router(
    routerConfig: router,
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
  );
  if (providers == null || providers.isEmpty) {
    await tester.pumpWidget(app);
  } else {
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: app),
    );
  }
  await tester.pump();
}

GoRoute _marker(String name, String label) => GoRoute(
      path: _pathFor(name),
      name: name,
      builder: (BuildContext context, GoRouterState state) =>
          OnboardingMarkerScreen(label: label),
    );

String? _nameFor(String path) => switch (path) {
      RoutePaths.onboarding => RouteNames.onboarding,
      RoutePaths.onboardingCapability => RouteNames.onboardingCapability,
      RoutePaths.onboardingProfile => RouteNames.onboardingProfile,
      RoutePaths.onboardingIndustry => RouteNames.onboardingIndustry,
      RoutePaths.onboardingIdentity => RouteNames.onboardingIdentity,
      RoutePaths.onboardingTradeProof => RouteNames.onboardingTradeProof,
      RoutePaths.onboardingComplete => RouteNames.onboardingComplete,
      RoutePaths.home => RouteNames.home,
      RoutePaths.verificationStatus => RouteNames.verificationStatus,
      _ => null,
    };

String _pathFor(String name) => switch (name) {
      RouteNames.onboarding => RoutePaths.onboarding,
      RouteNames.onboardingCapability => RoutePaths.onboardingCapability,
      RouteNames.onboardingProfile => RoutePaths.onboardingProfile,
      RouteNames.onboardingIndustry => RoutePaths.onboardingIndustry,
      RouteNames.onboardingIdentity => RoutePaths.onboardingIdentity,
      RouteNames.onboardingTradeProof => RoutePaths.onboardingTradeProof,
      RouteNames.onboardingComplete => RoutePaths.onboardingComplete,
      RouteNames.home => RoutePaths.home,
      RouteNames.verificationStatus => RoutePaths.verificationStatus,
      _ => RoutePaths.onboarding,
    };

/// A [LocalStore]-backed [HiveOnboardingProgressStore] over the in-memory
/// storage engine (Hive driver not required for contract tests).
HiveOnboardingProgressStore hiveProgressStore({LocalStore? store}) =>
    HiveOnboardingProgressStore(store: store ?? LocalStore(FakeStorageEngine()));