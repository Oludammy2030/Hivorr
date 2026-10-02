import 'package:hivorr/app/entry/entry_platform.dart';
import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/core/authentication/guards/auth_guard.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

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
    this.adminReviewProvider,
    this.entryStateProvider,
    this.environment = AppEnvironment.production,
    Uri? baseUri,
  }) : guard = AuthGuard(isAuthenticated: () => authProvider.isSignedIn),
       _developmentOnboardingDeepLink = _resolveDevelopmentOnboardingDeepLink(
         environment,
         baseUri ?? Uri.base,
       );

  final AuthProvider authProvider;
  final OnboardingProvider? onboardingProvider;

  /// The admin review provider surfaced to the widget tree (EP-02-11).
  ///
  /// Admin routes are not redirected here — the admin screens run
  /// [AdminReviewProvider.checkAdmin] themselves and fail closed internally.
  /// The provider is kept on the guard so its changes participate in the
  /// merged `refreshListenable` (route re-evaluation) and so callers can wire
  /// the seams without a separate listenable.
  final AdminReviewProvider? adminReviewProvider;

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
      // Email verification is a gate ahead of the main onboarding: an
      // authenticated session with an unverified email may only occupy the
      // verification screen. Fail-closed — it cannot reach home or onboarding.
      final AuthSession? session = authProvider.currentSession;
      final String? sessionEmail = session?.email;
      final bool unverified =
          session != null &&
          !session.isEmailConfirmed &&
          sessionEmail != null &&
          sessionEmail.isNotEmpty;
      if (unverified) {
        // The verification gate is the only permitted destination; allow it
        // outright (its resume mode sends the code), redirect others to it.
        if (location.startsWith(RoutePaths.authConfirmation)) {
          return null;
        }
        return _verificationGateResumeTarget(sessionEmail);
      }
      if (guard.isPublicRoute(location)) {
        if (AdminGate.isAdmin(adminReviewProvider)) {
          return RoutePaths.adminDashboard;
        }
        return RoutePaths.dashboard;
      }

      // Admin routes (/admin/*) are not fully gated at the router level
      // for read: the admin screens enforce authorization internally via the
      // AdminGate fail-closed "Admin access required" state.

      final String? onboardingRedirect = _onboardingResumeRedirect(location);
      if (onboardingRedirect != null) {
        return onboardingRedirect;
      }

      // Super Admins always land on the control panel (staging + production).
      // Every other complete entity lands on the role-aware dashboard.
      // Hydration is async: isAdmin is null before first checkAdmin(), so
      // the home redirect is deferred until the flag hydrates (via
      // refreshListenable on adminReviewProvider) to avoid flashing the
      // Both dashboard. Onboarding takes precedence above so an incomplete
      // wizard still resumes. HomeScreen mirrors this and waits as well.
      if (location == RoutePaths.home) {
        if (AdminGate.isAdmin(adminReviewProvider)) {
          return RoutePaths.adminDashboard;
        }
        // Defer only when the admin seam exists but has not hydrated yet.
        // When no admin provider is wired (unit tests / isolated shells),
        // preserve the legacy forward to the dashboard.
        if (adminReviewProvider != null &&
            adminReviewProvider?.isAdmin == null) {
          return null;
        }
        return RoutePaths.dashboard;
      }

      // Super-admin landing on the role-aware dashboard root goes to the
      // control panel. Sub-routes (/dashboard/...) stay manually reachable
      // so an admin can still verify the Both experience when needed.
      if (location == RoutePaths.dashboard &&
          AdminGate.isAdmin(adminReviewProvider)) {
        return RoutePaths.adminDashboard;
      }

      // Capability gate for dashboard sub-routes (EP-04-03): hiring-only
      // destinations require hire|both, work-only destinations require
      // offer|both. Shared destinations (overview, job detail, hires,
      // messages, notifications, account, settings) stay open — the server
      // remains authoritative per row (PLT002/PLT004 on misuse).
      final String? dashboardRedirect = _dashboardCapabilityRedirect(location);
      if (dashboardRedirect != null) {
        return dashboardRedirect;
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

  /// The verification gate in resume mode for an unverified email — the gate
  /// issues a fresh code on entry, so a returning user completes verification
  /// and only then reaches the main onboarding.
  static String _verificationGateResumeTarget(String email) =>
      '${RoutePaths.authConfirmation}?email='
      '${Uri.encodeQueryComponent(email)}'
      '&mode=${RoutePaths.authVerificationResumeMode}';

  /// Entry gate for incomplete entities (EP-02-18 §5.5, FV-44):
  ///
  /// * placeholder home or any dashboard route + hydrated incomplete wizard
  ///   → the resume step — unless the wizard was deliberately exited
  ///   ([OnboardingProvider.exited]), in which case home stays reachable so
  ///   its "Continue registration" action can drive the return (clearing the
  ///   flag re-engages this redirect);
  /// * any onboarding route + completed wizard → dashboard.
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
    // Server-authoritative completion wins (Rule 2/3): the backend decides
    // whether onboarding is finished, so a refresh (volatile local store
    // cleared) never re-enters a completed wizard. Falls back to the local
    // derivation only when the server state is unknown (no repository seam /
    // offline hydration failure).
    final bool complete =
        onboarding.isCompleteAuthoritative ?? onboarding.isComplete;
    if ((location == RoutePaths.home ||
            location.startsWith('${RoutePaths.dashboard}/') ||
            location == RoutePaths.dashboard) &&
        !complete &&
        !onboarding.exited) {
      return RoutePaths.onboardingRouteFor(step);
    }
    if (location.startsWith(RoutePaths.onboarding) && complete) {
      return RoutePaths.dashboard;
    }
    return null;
  }

  /// Capability gate for dashboard sub-routes (EP-04-03).
  ///
  /// Hiring-only destinations (`/dashboard/jobs` except detail, payments)
  /// require capability hire|both; work-only destinations (opportunities,
  /// earnings) require offer|both. `/dashboard/applications` is shared:
  /// professionals see their own applications, clients see the Jobs +
  /// Applicants inbox. Pre-hydration (null capability) allows navigation —
  /// the default `both` keeps the user unstranded and the server enforces
  /// per-row authority.
  String? _dashboardCapabilityRedirect(String location) {
    if (!location.startsWith('${RoutePaths.dashboard}/') &&
        location != RoutePaths.dashboard) {
      return null;
    }
    final EntityCapability capability =
        onboardingProvider?.progress?.capability ?? EntityCapability.both;
    final bool hire = capability != EntityCapability.offer;
    final bool offer = capability != EntityCapability.hire;
    if (!hire && _isHiringRoute(location)) {
      return RoutePaths.dashboard;
    }
    if (!offer && _isWorkRoute(location)) {
      return RoutePaths.dashboard;
    }
    return null;
  }

  static bool _isHiringRoute(String location) {
    if (location == RoutePaths.dashboardJobs ||
        location == RoutePaths.dashboardJobNew ||
        location.endsWith('/edit') ||
        location == RoutePaths.dashboardPayments) {
      return true;
    }
    return false;
  }

  static bool _isWorkRoute(String location) =>
      location == RoutePaths.dashboardOpportunities ||
      location == RoutePaths.dashboardEarnings;

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
