/// Compile-time route name constants (GoRouter route identifiers).
///
/// Use these instead of string literals to avoid typos and to enable
/// rename-safe navigation (e.g. `context.goNamed(RouteNames.profile)`).
abstract final class RouteNames {
  const RouteNames._();

  static const String home = 'home';
  static const String login = 'login';
  static const String signup = 'signup';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';

  /// Public Web landing experience (pre-registration, SEO-targetable).
  static const String welcome = 'welcome';

  /// Public Website information pages (public navigation, SEO-targetable).
  static const String about = 'about';
  static const String howItWorks = 'how-it-works';
  static const String features = 'features';
  static const String pricing = 'pricing';
  static const String security = 'security';
  static const String contact = 'contact';
  static const String help = 'help';

  /// Email-confirmation gate shown after a sign-up that requires confirmation.
  static const String authConfirmation = 'auth-confirmation';

  /// Native first-launch welcome for newly installed Android/iOS apps.
  static const String intro = 'intro';

  static const String profile = 'profile';
  static const String settings = 'settings';
  static const String publicProfile = 'public-profile';
  static const String publicStore = 'public-store';
  static const String verificationIdentity = 'verification-identity';
  static const String verificationStatus = 'verification-status';
  static const String tradeProofUpload = 'trade-proof-upload';
  static const String tradeVerificationStatus = 'trade-verification-status';
  static const String adminReviewQueue = 'admin-review-queue';
  static const String adminVerificationApprovals =
      'admin-verification-approvals';
  static const String adminReviewDetail = 'admin-review-detail';
  static const String adminDashboard = 'admin-dashboard';

  /// Manage User routes (EP-02-11 admin console).
  static const String adminManageUsers = 'admin-manage-users';
  static const String adminManageUsersProfessionals =
      'admin-manage-users-professionals';
  static const String adminManageUsersClients = 'admin-manage-users-clients';
  static const String adminManageUserDetail = 'admin-manage-user-detail';

  /// Admin Jobs & Projects (EP-04-03).
  static const String adminJobs = 'admin-jobs';

  /// Admin Payments (platform money-movement operations).
  static const String adminPayments = 'admin-payments';

  /// Admin Settings (staged platform configuration).
  static const String adminSettings = 'admin-settings';

  /// Financial profile routes (EP-02-13).
  static const String finance = 'finance';
  static const String financeCreate = 'finance-create';

  /// Escrow routes (EP-02-14).
  static const String escrow = 'escrow';
  static const String escrowDetail = 'escrow-detail';

  /// Currency-conversion route (EP-02-15).
  static const String convert = 'convert';

  /// Service listing owner-management routes (EP-03-08).
  static const String serviceListingsMine = 'service-listings-mine';
  static const String serviceListingNew = 'service-listing-new';
  static const String serviceListingEdit = 'service-listing-edit';
  static const String serviceListingMedia = 'service-listing-media';

  /// Public discovery routes (EP-03-09).
  static const String serviceDiscovery = 'service-discovery';
  static const String serviceSearch = 'service-search';
  static const String serviceDetail = 'service-detail';
  static const String serviceSeoDetail = 'service-seo-detail';

  /// Dispute routes (EP-02-17).
  static const String disputes = 'disputes';
  static const String disputesNew = 'disputes-new';
  static const String disputeDetail = 'dispute-detail';
  static const String disputesEvidenceNew = 'disputes-evidence-new';

  /// KYC status + upgrade routes (EP-02-12).
  static const String kycStatus = 'kyc-status';
  static const String kycUpgrade = 'kyc-upgrade';

  /// Unified-account activity launcher (Explore / Earn).
  static const String activities = 'activities';

  /// Onboarding wizard routes (EP-02-18) — capability-first, no profile step.
  static const String onboarding = 'onboarding';
  static const String onboardingCapability = 'onboarding-capability';
  static const String onboardingIndustry = 'onboarding-industry';
  static const String onboardingIdentity = 'onboarding-identity';
  static const String onboardingTradeProof = 'onboarding-trade-proof';
  static const String onboardingComplete = 'onboarding-complete';

  /// Service contract engagement routes (EP-03-10).
  static const String contracts = 'contracts';
  static const String contractNew = 'contract-new';
  static const String contractDetail = 'contract-detail';
  static const String contractMilestonesEdit = 'contract-milestones-edit';

  /// Scheduling routes (EP-03-14).
  static const String availability = 'availability';
  static const String appointmentBook = 'appointment-book';
  static const String appointmentDetail = 'appointment-detail';

  /// Double-blind review routes (EP-03-12).
  static const String contractReview = 'contract-review';
  static const String contractReviews = 'contract-reviews';

  /// Role-aware dashboard routes (EP-04-03).
  static const String dashboard = 'dashboard';
  static const String dashboardJobs = 'dashboard-jobs';
  static const String dashboardJobNew = 'dashboard-job-new';
  static const String dashboardJobDetail = 'dashboard-job-detail';
  static const String dashboardJobEdit = 'dashboard-job-edit';
  static const String dashboardServices = 'dashboard-services';
  static const String dashboardOpportunities = 'dashboard-opportunities';
  static const String dashboardApplications = 'dashboard-applications';
  static const String dashboardHires = 'dashboard-hires';
  static const String dashboardHireDetail = 'dashboard-hire-detail';
  static const String dashboardMessages = 'dashboard-messages';
  static const String dashboardMessageThread = 'dashboard-message-thread';
  static const String dashboardNotifications = 'dashboard-notifications';
  static const String dashboardPayments = 'dashboard-payments';
  static const String dashboardEarnings = 'dashboard-earnings';
  static const String dashboardAccount = 'dashboard-account';
  static const String dashboardSettings = 'dashboard-settings';
}
