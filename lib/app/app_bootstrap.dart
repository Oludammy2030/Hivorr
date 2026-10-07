import 'package:flutter/material.dart';

import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/startup/initialization_screen.dart';
import 'package:hivorr/config/app_config/app_config.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/config/wallet/wallet_conversion_rates_seed.dart';
import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/core/database/database.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:hivorr/core/storage/supabase_storage_service.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/data/data_layer.dart';
import 'package:hivorr/data/local/entry_state_store.dart';
import 'package:hivorr/engine/search_engine/service_search_index.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_orchestrator.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/portfolio/portfolio_dependency_injection.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';
import 'package:hivorr/systems/verification/services/identity_verification_service.dart';
import 'package:hivorr/systems/verification/services/trade_verification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a successful bootstrap initialization sequence.
///
/// Returned to callers that need the wired artifacts (e.g. the root widget).
class BootstrapResult {
  const BootstrapResult({
    required this.appConfig,
    required this.apiLayer,
    required this.authLayer,
    required this.localeProvider,
    required this.taxonomyRepository,
    required this.taxonomyProvider,
    this.marketplaceSearchRepository,
    this.marketplaceSearchProvider,
    this.marketplaceSearchIndex,
    this.serviceListingRepository,
    this.serviceListingProvider,
    this.serviceListingService,
    this.serviceContractRepository,
    this.serviceContractProvider,
    this.serviceContractService,
    this.contractEscrowOrchestrator,
    required this.verificationRepository,
    required this.verificationProvider,
    this.escrowRepository,
    this.escrowProvider,
    this.conversionRepository,
    this.conversionProvider,
    this.financialRepository,
    this.financialProvider,
    this.payoutRepository,
    this.payoutProvider,
    this.depositRepository,
    this.depositProvider,
    this.disputeRepository,
    this.disputeProvider,
    this.jobRepository,
    this.jobProvider,
    this.hireRepository,
    this.hireProvider,
    this.messagingRepository,
    this.messagingProvider,
    this.onboardingService,
    this.onboardingProvider,
    this.onboardingStore,
    required this.entryStore,
    required this.entryStateProvider,
    this.portfolioRepository,
    this.portfolioProvider,
    this.portfolioService,
    this.adminReviewRepository,
    this.adminReviewProvider,
    this.manageUserRepository,
    this.manageUserProvider,
    this.adminConfigProvider,
  });

  final AppConfig appConfig;
  final ApiLayer apiLayer;
  final AuthLayer authLayer;
  final LocaleProvider localeProvider;

  /// Cache-first taxonomy repository (EP-02-07).
  final TaxonomyRepository taxonomyRepository;

  /// Taxonomy provider surfaced to the widget tree (EP-02-07).
  final TaxonomyProvider taxonomyProvider;

  /// Ranked marketplace-search repository (EP-03-07). Optional for testability.
  final ServiceSearchRepository? marketplaceSearchRepository;

  /// Ranked marketplace-search provider surfaced to the widget tree (EP-03-07).
  final MarketplaceSearchProvider? marketplaceSearchProvider;

  /// Offline-browse cache warmer for ranked discovery (EP-03-07). Optional
  /// for testability; ranking stays server-decided (`AGENT.md:7`).
  final ServiceSearchIndex? marketplaceSearchIndex;

  /// Service listing owner repository (EP-03-08). Wired for the EP-03-09
  /// detail re-read (`service_listing_get`) and favorite toggle
  /// (`service_favorite_toggle`); also serves the owner screens that already
  /// consume the provider/service from the tree.
  final ServiceListingRepository? serviceListingRepository;

  /// Service listing provider surfaced to the widget tree (EP-03-08/09).
  final ServiceListingProvider? serviceListingProvider;

  /// Service listing facade surfaced to the widget tree (EP-03-08/09,
  /// media URL resolution + favorite toggle).
  final ServiceListingService? serviceListingService;

  /// Service contract engagement repository (EP-03-10). Optional for
  /// testability.
  final ServiceContractRepository? serviceContractRepository;

  /// Service contract provider surfaced to the widget tree (EP-03-10).
  final ServiceContractProvider? serviceContractProvider;

  /// Contract facade surfaced to the widget tree (EP-03-10, offer/accept
  /// orchestration + evidence URL resolution).
  final ContractService? serviceContractService;

  /// Verification-gated escrow release orchestrator (EP-03-11). Composes the
  /// contract verification half with the escrow proxy-seamed fund-movement
  /// half; the contract detail screen consumes it for `Verify & release`.
  /// Optional for testability (screens degrade to verify-only guidance).
  final ContractEscrowOrchestrator? contractEscrowOrchestrator;

  /// Identity-verification repository (EP-02-10).
  final VerificationRepository verificationRepository;

  /// Identity-verification provider surfaced to the widget tree (EP-02-10).
  final VerificationProvider verificationProvider;

  /// Escrow repository (EP-02-14). Optional for testability.
  final EscrowRepository? escrowRepository;

  /// Escrow provider surfaced to the widget tree (EP-02-14).
  final EscrowProvider? escrowProvider;

  /// Currency-conversion repository (EP-02-15). Optional for testability.
  final ConversionRepository? conversionRepository;

  /// Currency-conversion provider surfaced to the widget tree (EP-02-15).
  final ConversionProvider? conversionProvider;

  /// Financial-profile repository (EP-02-13). Optional for testability.
  final FinancialRepository? financialRepository;

  /// Financial-profile provider surfaced to the widget tree (EP-02-13).
  final FinancialProvider? financialProvider;

  /// Payout-account repository (EP-02-16). Optional for testability.
  final FinancialPayoutRepository? payoutRepository;

  /// Payout-account provider surfaced to the widget tree (EP-02-16).
  final FinancialPayoutProvider? payoutProvider;

  /// Deposit-read repository (EP-02-16). Optional for testability.
  final FinancialDepositRepository? depositRepository;

  /// Deposit provider surfaced to the widget tree (EP-02-16).
  final FinancialDepositProvider? depositProvider;

  /// Dispute-resolution repository (EP-02-17). Optional for testability.
  final DisputeRepository? disputeRepository;

  /// Dispute-resolution provider surfaced to the widget tree (EP-02-17).
  final DisputeProvider? disputeProvider;

  /// Jobs/applications repository (EP-04-01). Optional for testability.
  final JobRepository? jobRepository;

  /// Jobs/applications provider surfaced to the widget tree (EP-04-01).
  final JobProvider? jobProvider;

  /// Quotations/hires repository (EP-04-02). Optional for testability.
  final HireRepository? hireRepository;

  /// Quotations/hires provider surfaced to the widget tree (EP-04-02).
  final HireProvider? hireProvider;

  /// Messaging repository (EP-04-04). Optional for testability.
  final MessagingRepository? messagingRepository;

  /// Messaging provider surfaced to the widget tree (EP-04-04).
  final MessagingProvider? messagingProvider;

  /// Onboarding service (EP-02-18). Optional for testability.
  final OnboardingService? onboardingService;

  /// Onboarding provider surfaced to the widget tree (EP-02-18).
  final OnboardingProvider? onboardingProvider;

  /// Onboarding progress store (EP-02-18). Optional for testability.
  final OnboardingProgressStore? onboardingStore;

  /// Entry-state store (first-launch flag + pending redirect) over the local
  /// storage engine (entry architecture §5).
  final EntryStateStore entryStore;

  /// Entry-state provider surfaced to the widget tree and the router guard.
  final EntryStateProvider entryStateProvider;

  /// Public professional profile repository (EP-02-19). Optional for testability.
  final PortfolioRepository? portfolioRepository;

  /// Public-profile provider surfaced to the widget tree (EP-02-19).
  final PortfolioProvider? portfolioProvider;

  /// Professional-profile facade consumed by the public screen (EP-02-19).
  final ProfessionalProfileService? portfolioService;

  /// Admin review repository (EP-02-11). Optional for testability.
  final AdminReviewRepository? adminReviewRepository;

  /// Admin review provider surfaced to the widget tree and router guard
  /// (EP-02-11).
  final AdminReviewProvider? adminReviewProvider;

  /// Manage User repository (EP-02-11). Optional for testability.
  final ManageUserRepository? manageUserRepository;

  /// Manage User provider surfaced to the widget tree (EP-02-11).
  final ManageUserProvider? manageUserProvider;

  /// Staged platform-configuration provider for Admin Settings. Optional for
  /// testability.
  final AdminConfigProvider? adminConfigProvider;
}

/// Orchestrates the application's initialization sequence and launch.
///
/// This is the single entrypoint that wires every EP-01 core system into a
/// functional application shell. The sequence is fail-closed: any step
/// throwing prevents the app from launching and renders a user-safe error
/// screen with retry (EP-01-15 §5.3).
class AppBootstrap {
  const AppBootstrap._();

  /// Executes the full initialization sequence with injectable steps.
  ///
  /// [loadConfig], [initializeApi], [initializeAuthLayer], and
  /// [initializeStorage] default to the production implementations. Tests
  /// inject fakes to verify ordering and failure behavior without a live
  /// backend.
  static Future<BootstrapResult> initialize({
    AppConfig Function() loadConfig = AppConfig.load,
    Future<ApiLayer> Function(EnvironmentConfig) initializeApi =
        ApiInitializer.initializeApi,
    AuthLayer Function(GoTrueClient, SupabaseClient, AuthConfig)
        initializeAuthLayer =
        _defaultInitializeAuth,
    Future<StorageEngine> Function(EnvironmentConfig) initializeStorage =
        _defaultInitializeStorage,
  }) async {
    final AppConfig appConfig = loadConfig();
    final ApiLayer apiLayer = await initializeApi(appConfig.environmentConfig);
    final AuthLayer authLayer = initializeAuthLayer(
      apiLayer.supabaseClient.auth,
      apiLayer.supabaseClient,
      AuthConfig.fromEnvironment(appConfig.environmentConfig),
    );
    await authLayer.provider.initialize();
    final StorageEngine storage = await initializeStorage(
      appConfig.environmentConfig,
    );
    final LocaleProvider localeProvider = LocaleProvider(
      config: defaultLocalizationConfig,
      storage: storage,
    );
    await localeProvider.initialize();
    final ({TaxonomyRepository repository, TaxonomyProvider provider})
    taxonomy = registerTaxonomyLayer(apiLayer);
    final ({
      ServiceSearchRepository repository,
      MarketplaceSearchProvider provider,
      ServiceSearchIndex index,
    })
    marketplaceSearch = registerMarketplaceSearchLayer(
      apiLayer,
      taxonomyRepository: taxonomy.repository,
      storageEngine: storage,
    );
    // EP-03-09 discovery detail + favorites (reuses the EP-03-08 owner
    // slice verbatim: `service_listing_get` re-read, `service_favorite_toggle`
    // read-through, `service-listing-media` public URL resolution). Wiring the
    // existing layer also serves the owner screens, which already resolve the
    // provider/service from the tree.
    final ({
      ServiceListingRepository repository,
      ServiceListingProvider provider,
      ServiceListingService service,
    })
    serviceListing = registerServiceListingLayer(
      apiLayer,
      storage: SupabaseStorageService(
        storageClient: apiLayer.supabaseClient.storage,
        dio: apiLayer.dio,
        tokenProvider: apiLayer.tokenProvider,
      ),
    );
    final ({VerificationRepository repository, VerificationProvider provider})
    verification = registerVerificationLayer(apiLayer);
    final ({EscrowRepository repository, EscrowProvider provider}) escrow =
        registerEscrowLayer(
          apiLayer,
          writeViaProxy: appConfig.escrowWriteViaProxyEnabled,
        );
    final ({FinancialRepository repository, FinancialProvider provider})
    financial = registerFinancialLayer(apiLayer);
    final ({
      FinancialPayoutRepository repository,
      FinancialPayoutProvider provider,
    })
    payout = registerPayoutLayer(apiLayer);
    final ({
      FinancialDepositRepository repository,
      FinancialDepositProvider provider,
    })
    deposit = registerDepositLayer(apiLayer);
    final ({ConversionRepository repository, ConversionProvider provider})
    conversion = registerConversionLayer(
      apiLayer,
      financialRepository: financial.repository,
      pairsConfig: WalletConversionPairsConfig(
        enabled: appConfig.conversionPairsEnabled,
        baseCrossRates: WalletConversionRatesSeed.baseCrossRates,
      ),
      historyReadEnabled: appConfig.conversionHistoryReadEnabled,
    );
    final ({DisputeRepository repository, DisputeProvider provider}) dispute =
        registerDisputeLayer(apiLayer);
    // EP-03-10 contract engagement slice (offer/accept/verify/close over the
    // EP-03-02 RPCs + `service-listing-media` evidence uploads). Wired for the
    // contract screens, which resolve the provider/service from the tree.
    final ({
      ServiceContractRepository repository,
      ServiceContractProvider provider,
      ContractService service,
    })
    serviceContract = registerServiceContractLayer(
      apiLayer,
      storage: SupabaseStorageService(
        storageClient: apiLayer.supabaseClient.storage,
        dio: apiLayer.dio,
        tokenProvider: apiLayer.tokenProvider,
      ),
    );
    final ({JobRepository repository, JobProvider provider}) jobs =
        registerJobsLayer(apiLayer);
    final ({HireRepository repository, HireProvider provider}) hires =
        registerHiresLayer(apiLayer);
    final ({MessagingRepository repository, MessagingProvider provider})
    messaging = registerMessagingLayer(
      apiLayer,
      storageEngine: storage,
      outbox: ActionQueue(
        engine: storage,
        config: appConfig.environmentConfig.syncConfig,
      ),
    );
    // EP-03-11 release orchestration (verify-before-release sequencing over
    // the contract + escrow services; fund movement stays proxy-seamed).
    // Built only when both halves are wired; screens degrade gracefully.
    final ContractEscrowOrchestrator contractEscrowOrchestrator =
        registerContractEscrowLayer(
          contractService: serviceContract.service,
          escrowService: EscrowService(repository: escrow.repository),
        );
    final ({
      OnboardingService service,
      OnboardingProvider provider,
      OnboardingProgressStore store,
    })
    onboarding = _registerOnboarding(apiLayer, storage, taxonomy, verification);
    final EntryStateStore entryStore = HiveEntryStateStore(
      store: LocalStore(storage),
    );
    final EntryStateProvider entryStateProvider = EntryStateProvider(
      store: entryStore,
    );
    await entryStateProvider.hydrate();
    final ({
      PortfolioRemoteDataSource dataSource,
      PortfolioRepository repository,
      PortfolioProvider provider,
      ProfessionalProfileService service,
    })
    portfolio = registerPortfolioLayer(apiLayer: apiLayer);
    final ({AdminReviewRepository repository, AdminReviewProvider provider})
    adminReview = registerAdminReviewLayer(apiLayer);
    final ({ManageUserRepository repository, ManageUserProvider provider})
    manageUser = registerManageUserLayer(apiLayer);
    final AdminConfigProvider adminConfig = AdminConfigProvider(
      storage: storage,
    );
    await adminConfig.load();
    return BootstrapResult(
      appConfig: appConfig,
      apiLayer: apiLayer,
      authLayer: authLayer,
      localeProvider: localeProvider,
      taxonomyRepository: taxonomy.repository,
      taxonomyProvider: taxonomy.provider,
      marketplaceSearchRepository: marketplaceSearch.repository,
      marketplaceSearchProvider: marketplaceSearch.provider,
      marketplaceSearchIndex: marketplaceSearch.index,
      serviceListingRepository: serviceListing.repository,
      serviceListingProvider: serviceListing.provider,
      serviceListingService: serviceListing.service,
      serviceContractRepository: serviceContract.repository,
      serviceContractProvider: serviceContract.provider,
      serviceContractService: serviceContract.service,
      contractEscrowOrchestrator: contractEscrowOrchestrator,
      verificationRepository: verification.repository,
      verificationProvider: verification.provider,
      escrowRepository: escrow.repository,
      escrowProvider: escrow.provider,
      conversionRepository: conversion.repository,
      conversionProvider: conversion.provider,
      financialRepository: financial.repository,
      financialProvider: financial.provider,
      payoutRepository: payout.repository,
      payoutProvider: payout.provider,
      depositRepository: deposit.repository,
      depositProvider: deposit.provider,
      disputeRepository: dispute.repository,
      disputeProvider: dispute.provider,
      jobRepository: jobs.repository,
      jobProvider: jobs.provider,
      hireRepository: hires.repository,
      hireProvider: hires.provider,
      messagingRepository: messaging.repository,
      messagingProvider: messaging.provider,
      onboardingService: onboarding.service,
      onboardingProvider: onboarding.provider,
      onboardingStore: onboarding.store,
      entryStore: entryStore,
      entryStateProvider: entryStateProvider,
      portfolioRepository: portfolio.repository,
      portfolioProvider: portfolio.provider,
      portfolioService: portfolio.service,
      adminReviewRepository: adminReview.repository,
      adminReviewProvider: adminReview.provider,
      manageUserRepository: manageUser.repository,
      manageUserProvider: manageUser.provider,
      adminConfigProvider: adminConfig,
    );
  }

  /// Composes the EP-02-18 onboarding layer from the registered data slices.
  ///
  /// Builds the two verification service facades over the already-wired
  /// repositories and the [EntityProvider] over the EP-01 data seam, then calls
  /// `registerOnboardingLayer` (plan §5.8, FV-43). Only called from
  /// `initialize`; extracted so the record types stay local to bootstrap.
  /// [storage] backs the cache-only [HiveOnboardingProgressStore].
  static ({
    OnboardingService service,
    OnboardingProvider provider,
    OnboardingProgressStore store,
  })
  _registerOnboarding(
    ApiLayer apiLayer,
    StorageEngine storage,
    ({TaxonomyRepository repository, TaxonomyProvider provider}) taxonomy,
    ({VerificationRepository repository, VerificationProvider provider})
    verification,
  ) {
    final EntityProvider entity = registerDataLayer(apiLayer);
    final IdentityVerificationService identityService =
        IdentityVerificationService(repo: verification.repository);
    final ({
      TradeVerificationRepository repository,
      TradeVerificationProvider provider,
    })
    trade = registerTradeVerificationLayer(apiLayer);
    final TradeVerificationService tradeService = TradeVerificationService(
      repo: trade.repository,
    );
    return registerOnboardingLayer(
      apiLayer: apiLayer,
      entityProvider: entity,
      taxonomyProvider: taxonomy.provider,
      identityVerification: identityService,
      tradeVerification: tradeService,
      storageEngine: storage,
    );
  }

  /// Initializes the Hive-backed storage subsystem and returns its engine.
  static Future<StorageEngine> _defaultInitializeStorage(
    EnvironmentConfig config,
  ) async {
    final Database db = await Database.initialize(config);
    return db.engine;
  }

  static AuthLayer _defaultInitializeAuth(
    GoTrueClient authClient,
    SupabaseClient supabaseClient,
    AuthConfig config,
  ) => initializeAuth(
    authClient: authClient,
    supabaseClient: supabaseClient,
    config: config,
  );

  /// Application entrypoint invoked from [main].
  ///
  /// Registers the lifecycle observer, then renders [InitializationScreen]
  /// which runs the bootstrap sequence, shows the brand splash, and swaps to
  /// the app shell on success or a user-safe error screen with retry on
  /// failure (never a raw crash).
  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    final AppLifecycleObserver lifecycleObserver = AppLifecycleObserver();
    WidgetsBinding.instance.addObserver(lifecycleObserver);

    runApp(InitializationScreen(lifecycleObserver: lifecycleObserver));
  }
}
