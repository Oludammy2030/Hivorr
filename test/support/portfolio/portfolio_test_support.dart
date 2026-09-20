import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/models/public_profile_dto.dart';
import 'package:hivorr/data/providers/portfolio_provider.dart';
import 'package:hivorr/data/repositories/portfolio_repository_impl.dart';
import 'package:hivorr/systems/portfolio/screens/professional_profile_screen.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../fakes/fake_portfolio.dart';

/// Fully wired, faked portfolio stack for screen, widget, and integration tests.
class PortfolioTestStack {
  const PortfolioTestStack({
    required this.remote,
    required this.repository,
    required this.provider,
    required this.service,
  });

  final FakePortfolioRemoteDataSource remote;
  final PortfolioRepositoryImpl repository;
  final PortfolioProvider provider;
  final ProfessionalProfileService service;

  List<SingleChildWidget> buildProviders() => <SingleChildWidget>[
    ChangeNotifierProvider<PortfolioProvider>.value(value: provider),
    Provider<ProfessionalProfileService>.value(value: service),
  ];
}

/// Builds the fake portfolio stack with in-memory collaborators.
PortfolioTestStack buildPortfolioStack({
  PublicProfileDto? result,
  ApiException? error,
  Completer<void>? gate,
  StorageService? storage,
  String seoBaseUrl = 'https://hivorr.com',
}) {
  final FakePortfolioRemoteDataSource remote = FakePortfolioRemoteDataSource(
    result: result,
    error: error,
  );
  remote.gate = gate;
  final PortfolioRepositoryImpl repository = PortfolioRepositoryImpl(
    remote: remote,
  );
  final PortfolioProvider provider = PortfolioProvider(repository: repository);
  final ProfessionalProfileService service = ProfessionalProfileService(
    provider: provider,
    storage: storage,
    seoBaseUrl: seoBaseUrl,
  );
  return PortfolioTestStack(
    remote: remote,
    repository: repository,
    provider: provider,
    service: service,
  );
}

/// Builds a GoRouter hosting the real public profile route so screen tests can
/// exercise real navigation through `/p/:slug/:id`.
GoRouter portfolioTestRouter({required String path}) {
  final GoRouter router = GoRouter(
    initialLocation: path,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.publicProfileRoute,
        name: RouteNames.publicProfile,
        builder: (BuildContext context, GoRouterState state) =>
            ProfessionalProfileScreen(
              profileId: state.pathParameters['id'] ?? '',
              routeSlug: state.pathParameters['slug'],
            ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

/// Pumps the real [ProfessionalProfileScreen] at [path] inside a GoRouter-
/// backed [MaterialApp] with the given [providers] injected.
Future<void> pumpPortfolioScreen(
  WidgetTester tester,
  List<SingleChildWidget> providers,
  String path,
) async {
  final GoRouter router = portfolioTestRouter(path: path);
  final Widget app = MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
  );
  await tester.pumpWidget(MultiProvider(providers: providers, child: app));
}
