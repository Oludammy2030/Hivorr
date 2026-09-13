import 'package:hivorr/app/entry/entry_platform.dart';
import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/authentication/guards/auth_guard.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';

/// Adapts the EP-01-09 [AuthGuard] to the GoRouter redirect flow.
///
/// This is the single point where EP-01-09 authorization decisions are applied
/// to navigation. No business logic lives here (AGENT.md Rule 4) — it wraps
/// [AuthGuard] and adds the entry rules for the pre-onboarding doors:
///
/// * the unauthenticated root (`/`) resolves to the platform entry point
///   ([EntryPlatform]): the Web landing `/welcome`, the mobile first-launch
///   `/intro`, or `/login` for native returnees;
/// * protected destinations requested while signed out are redirected to the
///   right door with their original target preserved as `?next=` (entry
///   architecture §4), so the invite/SEO flow resumes after sign-up.
///
/// EP-02-18 §5.5: when an [onboardingProvider] is supplied, an authenticated
/// entity with a hydrated, incomplete wizard is redirected from the placeholder
/// home to its resume point (`/onboarding/{step}`) — the redirect is keyed on
/// [OnboardingProvider.loadProgress] hydration, never a screen.
class RouteGuard {
  RouteGuard({
    required this.authProvider,
    this.onboardingProvider,
    this.entryStateProvider,
    this.environment = AppEnvironment.production,
    Uri? baseUri,
  }) : guard = AuthGuard(
          isAuthenticated: () => authProvider.isSignedIn,
        ),
        _developmentOnboardingDeepLink = _resolveDevelopmentOnboardingDeepLink(
          environment,
          baseUri ?? Uri.base,
        );

  final AuthProvider authProvider;
  final OnboardingProvider? onboardingProvider;

  /// Device-local entry state (first-launch flag, pending redirect). Optional
  /// for testability; drives the `/` entry decision for native builds.
  final EntryStateProvider? entryStateProvider;

  /// Development-only: the onboarding route the browser asked for at page
  /// load, captured before GoRouter syncs the address bar (EP-02-18 UAT).
  final String? _developmentOnboardingDeepLink;

  /// The active build environment (EP-01-03).
  ///
  /// Defaults to [AppEnvironment.production] so any caller that omits it stays
  /// fail-closed; only [AppEnvironment.development] enables the unauthenticated
  /// wizard preview seam below.
  final AppEnvironment environment;

  final AuthGuard guard;

  /// Resolves a redirect target for the given [location].
  ///
  /// Returns `null` to allow the navigation, or a path string to redirect to.
  /// Delegates public-route classification to [AuthGuard.publicRoutePrefixes]
  /// and the platform-entry decision to [_entryPathForUnauthenticated].
  String? redirectResolver(String location) {
    final bool authenticated = authProvider.isSignedIn;

    // Authenticated users should not land on public-only auth screens.
    if (authenticated) {
      if (guard.isPublicRoute(location)) {
        return RoutePaths.home;
      }
      final String? onboardingRedirect =
          _onboardingResumeRedirect(location);
      if (onboardingRedirect != null) {
        return onboardingRedirect;
      }
      return null;
    }

    // Public auth screens and public content routes are always allowed.
    if (guard.isPublicRoute(location) || _isPublicContentView(location)) {
      return null;
    }

    // Development-only UAT seam (EP-02-18 DoD, UA-01..09): let an
    // unauthenticated reviewer open the onboarding wizard directly. Has no
    // effect outside development, and never applies to protected routes.
    if (environment.isDevelopment && _isOnboardingRoute(location)) {
      return null;
    }

    // Development-only UAT boot redirect: a cold start at an onboarding deep
    // link resolves the web initial location to `/` (the hash is not part of
    // boot routing) and would fail-closed to `/login`; honour the requested
    // wizard instead. Never active outside development.
    final String? developmentDeepLink = _developmentOnboardingDeepLink;
    if (developmentDeepLink != null &&
        location == RoutePaths.home &&
        !authenticated) {
      return developmentDeepLink;
    }

    // The unauthenticated root resolves to the platform's entry door.
    if (location == RoutePaths.home) {
      return _entryPathForUnauthenticated();
    }

    // Fail-closed: any other (protected) route redirects to the platform's
    // entry door, preserving the original destination as `?next=` so the
    // visitor resumes the invite/SEO flow after sign-up.
    return _contextPreservingEntryRedirect(location);
  }

  /// The platform entry target for an unauthenticated root request:
  ///
  /// * Web builds → the public landing (`/welcome`, SEO door);
  /// * Native builds → the one-time intro on first launch, else `/login` for
  ///   returning visitors (entry architecture §4).
  String _entryPathForUnauthenticated() {
    if (EntryPlatform.isWeb) {
      return RoutePaths.welcome;
    }
    final EntryStateProvider? entryState = entryStateProvider;
    if (entryState != null && !entryState.introSeen) {
      return RoutePaths.intro;
    }
    return RoutePaths.login;
  }

  /// Fail-closed redirect that preserves [location] as `?next=`.
  String _contextPreservingEntryRedirect(String location) {
    final String entryTarget = _entryPathForUnauthenticated();
    if (location.isEmpty) {
      return entryTarget;
    }
    return '$entryTarget?next=$location';
  }

  /// Entry gate for incomplete entities (EP-02-18 §5.5, FV-44):
  ///
  /// * placeholder home + hydrated incomplete wizard → the resume step;
  /// * any onboarding route + completed wizard → home.
  ///
  /// `null` when the provider is absent or not hydrated yet (no redirect beats
  /// a wrong redirect; the merged `refreshListenable` re-runs this once
  /// hydration completes).
  String? _onboardingResumeRedirect(String location) {
    final OnboardingProvider? onboarding = onboardingProvider;
    if (onboarding == null) {
      return null;
    }
    final OnboardingStepCode? step = onboarding.currentStep;
    if (step == null) {
      return null;
    }
    if (location == RoutePaths.home && !onboarding.isComplete) {
      return RoutePaths.onboardingRouteFor(step);
    }
    if (location.startsWith(RoutePaths.onboarding) && onboarding.isComplete) {
      return RoutePaths.home;
    }
    return null;
  }

  static bool _isPublicContentView(String location) =>
      location.startsWith('/p/') || location.startsWith('/store/');

  /// Whether [location] is any EP-02-18 onboarding route (base or sub-step).
  static bool _isOnboardingRoute(String location) =>
      location == RoutePaths.onboarding ||
      location.startsWith('${RoutePaths.onboarding}/');

  /// Captures an onboarding deep link present in the initial web URL.
  ///
  /// Runs at guard construction, before GoRouter processes the boot location
  /// and overwrites the address bar. The web hash strategy keeps routes in the
  /// `#/...` fragment, so both the fragment and the bare path are checked.
  /// Returns `null` outside development so the guard stays fail-closed.
  static String? _resolveDevelopmentOnboardingDeepLink(
    AppEnvironment environment,
    Uri baseUri,
  ) {
    if (!environment.isDevelopment) {
      return null;
    }
    final String fragment = baseUri.fragment;
    if (fragment.isNotEmpty && _isOnboardingRoute(fragment)) {
      return fragment;
    }
    if (_isOnboardingRoute(baseUri.path)) {
      return baseUri.path;
    }
    return null;
  }
}