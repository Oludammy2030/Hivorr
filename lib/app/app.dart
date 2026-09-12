import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/router/app_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/providers/conversion_provider.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/conversion_repository.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';
import 'package:hivorr/data/repositories/escrow_repository.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/data/repositories/financial_repository.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Root application widget for the Hivorr platform.
///
/// Composes [MultiProvider] (auth, locale, taxonomy + future core providers)
/// with [MaterialApp.router] bound to the GoRouter instance. Theming is sourced
/// exclusively from [AppTheme] tokens (AGENT.md Rule 5).
class HivorrApp extends StatefulWidget {
  const HivorrApp({
    super.key,
    required this.authProvider,
    required this.localeProvider,
    required this.lifecycleObserver,
    required this.taxonomyRepository,
    required this.taxonomyProvider,
    this.verificationRepository,
    this.verificationProvider,
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
    this.onboardingService,
    this.onboardingProvider,
    this.onboardingStore,
    this.platformFilePicker,
    this.environment = AppEnvironment.production,
  });

  final AuthProvider authProvider;
  final LocaleProvider localeProvider;
  final AppLifecycleObserver lifecycleObserver;
  final TaxonomyRepository taxonomyRepository;
  final TaxonomyProvider taxonomyProvider;

  /// Identity-verification repository (EP-02-10). Optional for testability.
  final VerificationRepository? verificationRepository;

  /// Identity-verification provider surfaced to the widget tree (EP-02-10).
  final VerificationProvider? verificationProvider;

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

  /// Onboarding service (EP-02-18). Optional for testability.
  final OnboardingService? onboardingService;

  /// Onboarding provider surfaced to the widget tree (EP-02-18).
  final OnboardingProvider? onboardingProvider;

  /// Onboarding progress store (EP-02-18). Optional for testability.
  final OnboardingProgressStore? onboardingStore;

  /// Real platform file picker surfaced to feature screens. Optional for
  /// testability; falls back to a fresh instance when omitted.
  final PlatformFilePicker? platformFilePicker;

  /// The active build environment (EP-01-03), used for dev-only seams.
  ///
  /// Defaults to [AppEnvironment.production] so test harnesses stay
  /// fail-closed; the bootstrap entrypoint passes the loaded environment.
  final AppEnvironment environment;

  @override
  State<HivorrApp> createState() => _HivorrAppState();
}

class _HivorrAppState extends State<HivorrApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.create(
      authProvider: widget.authProvider,
      onboardingProvider: widget.onboardingProvider,
      environment: widget.environment,
    );
    widget.authProvider.addListener(_hydrateOnboarding);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateOnboarding());
  }

  @override
  void dispose() {
    _router.dispose();
    widget.authProvider.removeListener(_hydrateOnboarding);
    widget.lifecycleObserver.dispose();
    super.dispose();
  }

  /// Hydrates (or re-keys) the wizard progress for the active entity after
  /// auth-bootstrap and on every account switch (EP-02-18 §5.5, FV-44).
  void _hydrateOnboarding() {
    final OnboardingProvider? onboarding = widget.onboardingProvider;
    if (onboarding == null || !widget.authProvider.isSignedIn) {
      return;
    }
    final String? entityId = widget.authProvider.currentEntityId;
    if (entityId == null || entityId.isEmpty) {
      return;
    }
    if (onboarding.entityId == entityId) {
      return;
    }
    unawaited(onboarding.loadProgress(entityId));
  }

  @override
  Widget build(BuildContext context) {
    final VerificationRepository? verificationRepository =
        widget.verificationRepository;
    final VerificationProvider? verificationProvider =
        widget.verificationProvider;
    final EscrowRepository? escrowRepository = widget.escrowRepository;
    final EscrowProvider? escrowProvider = widget.escrowProvider;
    final ConversionRepository? conversionRepository =
        widget.conversionRepository;
    final ConversionProvider? conversionProvider = widget.conversionProvider;
    final FinancialRepository? financialRepository =
        widget.financialRepository;
    final FinancialProvider? financialProvider = widget.financialProvider;
    final FinancialPayoutRepository? payoutRepository = widget.payoutRepository;
    final FinancialPayoutProvider? payoutProvider = widget.payoutProvider;
    final FinancialDepositRepository? depositRepository =
        widget.depositRepository;
    final FinancialDepositProvider? depositProvider = widget.depositProvider;
    final DisputeRepository? disputeRepository = widget.disputeRepository;
    final DisputeProvider? disputeProvider = widget.disputeProvider;
    final OnboardingService? onboardingService = widget.onboardingService;
    final OnboardingProvider? onboardingProvider = widget.onboardingProvider;
    final OnboardingProgressStore? onboardingStore = widget.onboardingStore;
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AuthProvider>.value(
          value: widget.authProvider,
        ),
        ChangeNotifierProvider<LocaleProvider>.value(
          value: widget.localeProvider,
        ),
        Provider<TaxonomyRepository>.value(value: widget.taxonomyRepository),
        ChangeNotifierProvider<TaxonomyProvider>.value(
          value: widget.taxonomyProvider,
        ),
        if (verificationRepository != null)
          Provider<VerificationRepository>.value(value: verificationRepository),
        if (verificationProvider != null)
          ChangeNotifierProvider<VerificationProvider>.value(
            value: verificationProvider,
          ),
        if (escrowRepository != null)
          Provider<EscrowRepository>.value(value: escrowRepository),
        if (escrowProvider != null)
          ChangeNotifierProvider<EscrowProvider>.value(
            value: escrowProvider,
          ),
        if (conversionRepository != null)
          Provider<ConversionRepository>.value(value: conversionRepository),
        if (conversionProvider != null)
          ChangeNotifierProvider<ConversionProvider>.value(
            value: conversionProvider,
          ),
        if (financialRepository != null)
          Provider<FinancialRepository>.value(value: financialRepository),
        if (financialProvider != null)
          ChangeNotifierProvider<FinancialProvider>.value(
            value: financialProvider,
          ),
        if (payoutRepository != null)
          Provider<FinancialPayoutRepository>.value(value: payoutRepository),
        if (payoutProvider != null)
          ChangeNotifierProvider<FinancialPayoutProvider>.value(
            value: payoutProvider,
          ),
        if (depositRepository != null)
          Provider<FinancialDepositRepository>.value(value: depositRepository),
        if (depositProvider != null)
          ChangeNotifierProvider<FinancialDepositProvider>.value(
            value: depositProvider,
          ),
        if (disputeRepository != null)
          Provider<DisputeRepository>.value(value: disputeRepository),
        if (disputeProvider != null)
          ChangeNotifierProvider<DisputeProvider>.value(
            value: disputeProvider,
          ),
        if (onboardingStore != null)
          Provider<OnboardingProgressStore>.value(value: onboardingStore),
        Provider<PlatformFilePicker>.value(
          value: widget.platformFilePicker ?? PlatformFilePicker(),
        ),
        if (onboardingService != null)
          Provider<OnboardingService>.value(value: onboardingService),
        if (onboardingProvider != null)
          ChangeNotifierProvider<OnboardingProvider>.value(
            value: onboardingProvider,
          ),
      ],
      child: Builder(
        builder: (BuildContext context) {
          final LocaleProvider localeProvider =
              context.watch<LocaleProvider>();
          return MaterialApp.router(
            title: 'Hivorr',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            routerConfig: _router,
            locale: localeProvider.currentLocale,
            supportedLocales: HivorrSupportedLocales.supported,
            localeResolutionCallback: HivorrSupportedLocales.resolve,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              HivorrLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
