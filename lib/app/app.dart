import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/router/app_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';
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
  });

  final AuthProvider authProvider;
  final LocaleProvider localeProvider;
  final AppLifecycleObserver lifecycleObserver;
  final TaxonomyRepository taxonomyRepository;
  final TaxonomyProvider taxonomyProvider;

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
