import 'package:hivorr/data/entities/onboarding_progress.dart';

/// Compile-time route path constants (GoRouter path patterns).
///
/// Path parameters use GoRouter syntax (`:param`). Use the typed builders
/// [publicProfile] / [publicStore] to produce fully-qualified, URL-encoded
/// paths for navigation and deep links (EP-01-15 §5.5).
abstract final class RoutePaths {
  const RoutePaths._();

  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  /// Public Web landing experience (pre-registration, SEO-targetable).
  static const String welcome = '/welcome';

  /// Public Website information pages (public navigation, SEO-targetable).
  static const String about = '/about';
  static const String howItWorks = '/how-it-works';
  static const String features = '/features';
  static const String pricing = '/pricing';
  static const String security = '/security';
  static const String contact = '/contact';
  static const String help = '/help';

  /// Email-confirmation gate shown after a sign-up that requires confirmation.
  static const String authConfirmation = '/auth/confirm';

  /// Query-param value that signals the gate should issue a fresh code on entry
  /// (login-resume and guard-redirect flows).
  static const String authVerificationResumeMode = 'resume';

  /// Native first-launch welcome for newly installed Android/iOS apps.
  static const String intro = '/intro';

  static const String profile = '/profile';
  static const String settings = '/settings';

  /// Identity-verification standalone screens (EP-02-10).
  static const String verificationIdentity = '/verification/identity';
  static const String verificationStatus = '/verification/status';

  /// Trade-verification screens (EP-02-11).
  static const String tradeProofUpload = '/verification/trade-proof';
  static const String tradeVerificationStatus = '/verification/trade/status';

  /// Super Admin shell root.
  static const String adminRoot = '/admin';

  /// Super Admin dashboard (landing).
  static const String adminDashboard = '/admin/dashboard';

  /// Admin review queue (EP-02-11). UI label: Verification & Approvals.
  static const String adminReviewQueue = '/admin/review-queue';

  /// Verification & Approvals alias (new canonical label).
  static const String adminVerificationApprovals = '/admin/review-queue';

  /// Admin review detail (EP-02-11, document viewer + audit trail).
  static const String adminReviewDetail = '/admin/review-queue/:submissionId';

  /// Manage User directory (EP-02-11 admin console). All Users.
  static const String adminManageUsers = '/admin/users';

  /// Filtered Users sub-routes (same population, capability-filtered).
  static const String adminUsersProfessionals = '/admin/users/professionals';
  static const String adminUsersClients = '/admin/users/clients';

  /// Manage User detail (EP-02-11 admin console, single-user posture).
  static const String adminManageUserDetail = '/admin/users/:userId';

  /// Admin Jobs & Projects (EP-04-03, platform hiring visibility).
  static const String adminJobs = '/admin/jobs';

  /// Admin Payments (platform money-movement operations).
  static const String adminPayments = '/admin/payments';

  /// Admin Settings (staged platform configuration).
  static const String adminSettings = '/admin/settings';

  /// KYC status + upgrade screens (EP-02-12).
  static const String kycStatus = '/verification/kyc';
  static const String kycUpgrade = '/verification/kyc/upgrade';

  /// Onboarding wizard routes (EP-02-18) — private authenticated flow, no SEO.
  ///
  /// Identity basics are captured at registration; the wizard starts at the
  /// capability decision, so no profile step route exists.
  static const String onboarding = '/onboarding';
  static const String onboardingCapability = '/onboarding/capability';
  static const String onboardingIndustry = '/onboarding/industry';
  static const String onboardingIdentity = '/onboarding/identity';
  static const String onboardingTradeProof = '/onboarding/trade-proof';
  static const String onboardingComplete = '/onboarding/complete';

  /// Unified-account activity launcher (Explore / Earn).
  ///
  /// Private authenticated route (no SEO): "Welcome to Hivorr — How would you
  /// like to use Hivorr?" One account, multiple activities; the screen stays
  /// reachable after onboarding so entities can add capabilities over time.
  static const String activities = '/activities';

  /// Maps a wizard step code to its bookmarkable location
  /// (EP-02-18 §5.7). `completed` maps to the completion screen.
  static String onboardingRouteFor(OnboardingStepCode step) => switch (step) {
    OnboardingStepCode.capability => onboardingCapability,
    OnboardingStepCode.industry => onboardingIndustry,
    OnboardingStepCode.identityDocument => onboardingIdentity,
    OnboardingStepCode.tradeProof => onboardingTradeProof,
  };

  /// Financial profile screens (EP-02-13).
  static const String finance = '/finance';
  static const String financeCreate = '/finance/create';

  /// Escrow screens (EP-02-14).
  static const String escrow = '/finance/escrow';
  static const String escrowDetail = '/finance/escrow/:id';

  /// Builds a URL-encoded escrow detail path (EP-03-11 contract linkage).
  static String escrowDetailFor(String id) =>
      '/finance/escrow/${Uri.encodeComponent(id)}';

  /// Dispute screens (EP-02-17).
  static const String disputes = '/support/disputes';
  static const String disputesNew = '/support/disputes/file/:escrowId';

  /// Builds a URL-encoded dispute-filing path for an escrow/contract id.
  static String disputesFile(String escrowId) =>
      '/support/disputes/file/${Uri.encodeComponent(escrowId)}';
  static const String disputeDetail = '/support/disputes/:id';
  static const String disputesEvidenceNew =
      '/support/disputes/:caseId/evidence/new';

  /// Currency-conversion screen (EP-02-15).
  static const String convert = '/finance/convert';

  /// Service listing owner-management screens (EP-03-08, protected).
  static const String serviceListingsMine = '/services/mine';
  static const String serviceListingNew = '/services/mine/new';
  static const String serviceListingEdit = '/services/mine/:id/edit';
  static const String serviceListingMedia = '/services/mine/:id/media';

  /// Builds a URL-encoded service listing edit path.
  static String serviceListingEditFor({required String id}) =>
      '/services/mine/${Uri.encodeComponent(id)}/edit';

  /// Builds a URL-encoded service listing media path.
  static String serviceListingMediaFor({required String id}) =>
      '/services/mine/${Uri.encodeComponent(id)}/media';

  /// Public service discovery browse (EP-03-09, `published` only).
  static const String serviceDiscovery = '/services';

  /// Public ranked search (EP-03-09). Optional query params: `q`, `profession`.
  static const String serviceSearch = '/services/search';

  /// Public service detail route. Parameter: `id` (authoritative).
  static const String serviceDetailRoute = '/services/:id';

  /// Builds a URL-encoded public service detail path.
  static String serviceDetail(String id) =>
      '/services/${Uri.encodeComponent(id)}';

  /// SEO alias for the public service detail (EP-03-09 route shape; canonical
  /// meta ships in EP-03-19). Parameters: `slug` (cosmetic), `id`.
  static const String serviceSeoDetailRoute = '/s/:slug/:id';

  /// Builds a URL-encoded SEO service detail path.
  static String serviceSeoDetail({required String slug, required String id}) =>
      '/s/${Uri.encodeComponent(slug)}/${Uri.encodeComponent(id)}';

  /// Public profile route. Parameters: `slug`, `id`.
  static const String publicProfileRoute = '/p/:slug/:id';

  /// Public store route. Parameter: `storeId`.
  static const String publicStoreRoute = '/store/:storeId';

  /// Builds a URL-encoded public profile path, e.g.
  /// `publicProfile(slug: 'electrician', id: 'abc-123')` → `/p/electrician/abc-123`.
  static String publicProfile({required String slug, required String id}) =>
      '/p/${Uri.encodeComponent(slug)}/${Uri.encodeComponent(id)}';

  /// Builds a URL-encoded public store path, e.g.
  /// `publicStore(storeId: 'xyz-456')` → `/store/xyz-456`.
  static String publicStore({required String storeId}) =>
      '/store/${Uri.encodeComponent(storeId)}';

  /// Service contract engagement screens (EP-03-10, protected).
  static const String contracts = '/contracts';
  static const String contractNew = '/contracts/new';
  static const String contractDetailRoute = '/contracts/:id';
  static const String contractMilestonesEditRoute =
      '/contracts/:id/milestones/edit';

  /// Builds a URL-encoded contract detail path.
  static String contractDetail(String id) =>
      '/contracts/${Uri.encodeComponent(id)}';

  /// Builds a URL-encoded contract offer path for a listing.
  static String contractOfferFor({required String listingId}) =>
      '/contracts/new?listingId=${Uri.encodeComponent(listingId)}';

  /// Builds a URL-encoded contract milestone editor path.
  static String contractMilestonesEdit(String id) =>
      '/contracts/${Uri.encodeComponent(id)}/milestones/edit';

  /// Role-aware dashboard shell root (EP-04-03).
  static const String dashboard = '/dashboard';

  /// Client hiring routes (hire focus).
  static const String dashboardJobs = '/dashboard/jobs';
  static const String dashboardJobNew = '/dashboard/jobs/new';
  static const String dashboardJobDetailRoute = '/dashboard/jobs/:id';
  static const String dashboardJobEditRoute = '/dashboard/jobs/:id/edit';

  /// Builds a URL-encoded dashboard job detail path.
  static String dashboardJobDetail(String id) =>
      '/dashboard/jobs/${Uri.encodeComponent(id)}';

  /// Builds a URL-encoded dashboard job edit path.
  static String dashboardJobEdit(String id) =>
      '/dashboard/jobs/${Uri.encodeComponent(id)}/edit';

  /// Client service discovery inside the dashboard shell (hire focus).
  ///
  /// Shell-persistent companion to the public [serviceDiscovery] browse: same
  /// ranked search/filter/results stack, but rendered as dashboard content so
  /// the sidebar and shell survive navigation. The public `/services` family
  /// stays untouched for anonymous/SEO entry.
  static const String dashboardServices = '/dashboard/services';

  /// Professional work routes (offer focus).
  static const String dashboardOpportunities = '/dashboard/opportunities';
  static const String dashboardApplications = '/dashboard/applications';

  /// Hires routes (either side; `?role=client|professional` scopes the list).
  static const String dashboardHires = '/dashboard/hires';
  static const String dashboardHireDetailRoute = '/dashboard/hires/:id';

  /// Builds a URL-encoded dashboard hire detail path.
  static String dashboardHireDetail(String id) =>
      '/dashboard/hires/${Uri.encodeComponent(id)}';

  /// Builds a URL-encoded dashboard message thread path.
  static String dashboardMessageThread(String id) =>
      '/dashboard/messages/${Uri.encodeComponent(id)}';

  /// Shared dashboard routes.
  static const String dashboardMessages = '/dashboard/messages';
  static const String dashboardMessageThreadRoute = '/dashboard/messages/:id';
  static const String dashboardNotifications = '/dashboard/notifications';
  static const String dashboardPayments = '/dashboard/payments';
  static const String dashboardEarnings = '/dashboard/earnings';
  static const String dashboardAccount = '/dashboard/account';
  static const String dashboardSettings = '/dashboard/settings';
}
