import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/router/app_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Root application widget for the Hivorr platform.
///
/// Composes [MultiProvider] (auth + future core providers) with
/// [MaterialApp.router] bound to the GoRouter instance. Theming is sourced
/// exclusively from [AppTheme] tokens (AGENT.md Rule 5).
class HivorrApp extends StatefulWidget {
  const HivorrApp({
    super.key,
    required this.authProvider,
    required this.lifecycleObserver,
  });

  final AuthProvider authProvider;
  final AppLifecycleObserver lifecycleObserver;

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
      ],
      child: MaterialApp.router(
        title: 'Hivorr',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
