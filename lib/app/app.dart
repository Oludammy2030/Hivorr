import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/router/app_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
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

  @override
  State<HivorrApp> createState() => _HivorrAppState();
}

class _HivorrAppState extends State<HivorrApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.create(authProvider: widget.authProvider);
  }

  @override
  void dispose() {
    _router.dispose();
    widget.lifecycleObserver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VerificationRepository? verificationRepository =
        widget.verificationRepository;
    final VerificationProvider? verificationProvider =
        widget.verificationProvider;
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
