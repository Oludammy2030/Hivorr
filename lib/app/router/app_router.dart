import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/auth/screens/auth_confirmation_gate_screen.dart';
import 'package:hivorr/app/auth/screens/forgot_password_screen.dart';
import 'package:hivorr/app/auth/screens/login_screen.dart';
import 'package:hivorr/app/auth/screens/register_screen.dart';
import 'package:hivorr/app/auth/screens/reset_password_screen.dart';
import 'package:hivorr/app/entry/entry_platform.dart';
import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/entry/screens/intro_screen.dart';
import 'package:hivorr/app/entry/screens/welcome_screen.dart';
import 'package:hivorr/app/home/home_screen.dart';
import 'package:hivorr/app/public/screens/about_screen.dart';
import 'package:hivorr/app/public/screens/contact_screen.dart';
import 'package:hivorr/app/public/screens/features_screen.dart';
import 'package:hivorr/app/public/screens/help_screen.dart';
import 'package:hivorr/app/public/screens/how_it_works_screen.dart';
import 'package:hivorr/app/public/screens/pricing_screen.dart';
import 'package:hivorr/app/public/screens/security_screen.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/admin/screens/admin_dashboard_screen.dart';
import 'package:hivorr/systems/admin/screens/admin_jobs_screen.dart';
import 'package:hivorr/systems/admin/screens/manage_user_detail_screen.dart';
import 'package:hivorr/systems/admin/screens/manage_user_screen.dart';
import 'package:hivorr/systems/admin/shell/super_admin_shell.dart';
import 'package:hivorr/systems/dashboard/screens/conversation_screen.dart';
import 'package:hivorr/systems/dashboard/screens/dashboard_overview_screen.dart';
import 'package:hivorr/systems/dashboard/screens/dashboard_settings_screen.dart';
import 'package:hivorr/systems/dashboard/screens/finance_hubs_screen.dart';
import 'package:hivorr/systems/dashboard/screens/hire_detail_screen.dart';
import 'package:hivorr/systems/dashboard/screens/hires_screen.dart';
import 'package:hivorr/systems/dashboard/screens/job_detail_screen.dart';
import 'package:hivorr/systems/dashboard/screens/job_form_screen.dart';
import 'package:hivorr/systems/dashboard/screens/messages_screen.dart';
import 'package:hivorr/systems/dashboard/screens/my_jobs_screen.dart';
import 'package:hivorr/systems/dashboard/screens/notifications_screen.dart';
import 'package:hivorr/systems/dashboard/screens/opportunities_screen.dart';
import 'package:hivorr/systems/dashboard/screens/profile_screen.dart';
import 'package:hivorr/systems/dashboard/shell/hivorr_dashboard_shell.dart';
import 'package:hivorr/systems/finance/screens/conversion_screen.dart';
import 'package:hivorr/systems/finance/screens/escrow_detail_screen.dart';
import 'package:hivorr/systems/finance/screens/escrow_list_screen.dart';
import 'package:hivorr/systems/finance/screens/financial_profile_creation_flow.dart';
import 'package:hivorr/systems/finance/screens/financial_profile_screen.dart';
import 'package:hivorr/systems/local_commerce/screens/store_screen.dart';
import 'package:hivorr/systems/marketplace/screens/my_listings_screen.dart';
import 'package:hivorr/systems/marketplace/screens/service_listing_form_screen.dart';
import 'package:hivorr/systems/marketplace/screens/service_listing_media_screen.dart';
import 'package:hivorr/systems/onboarding/screens/onboarding_shell_screen.dart';
import 'package:hivorr/systems/portfolio/screens/professional_profile_screen.dart';
import 'package:hivorr/systems/support/screens/dispute_detail_screen.dart';
import 'package:hivorr/systems/support/screens/dispute_evidence_form_screen.dart';
import 'package:hivorr/systems/support/screens/dispute_filing_screen.dart';
import 'package:hivorr/systems/support/screens/dispute_list_screen.dart';
import 'package:hivorr/systems/verification/screens/admin_review_detail_screen.dart';
import 'package:hivorr/systems/verification/screens/admin_review_queue_screen.dart';
import 'package:hivorr/systems/verification/screens/identity_document_upload_screen.dart';
import 'package:hivorr/systems/verification/screens/kyc_status_screen.dart';
import 'package:hivorr/systems/verification/screens/kyc_upgrade_screen.dart';
import 'package:hivorr/systems/verification/screens/trade_proof_upload_screen.dart';
import 'package:hivorr/systems/verification/screens/trade_verification_status_screen.dart';
import 'package:hivorr/systems/verification/screens/verification_status_screen.dart';

/// Builds the application [GoRouter] with the full route tree.
///
/// Route protection is delegated to [RouteGuard] (which wraps the EP-01-09
/// [AuthGuard]). [refreshListenable] is bound to [AuthProvider] so route
/// re-evaluation fires on every auth-state change.
///
/// The EP-02-10 verification screens are registered here and consume a
/// [VerificationProvider] supplied by the app shell (`HivorrApp` MultiProvider,
/// mirroring `TaxonomyProvider`) — the router never constructs providers.
class AppRouter {
  const AppRouter._();

  /// Builds the router. The optional [onboardingProvider] powers the
  /// EP-02-18 resume gate ([RouteGuard]) and is merged into `refreshListenable`
  /// so the entry redirect fires once wizard hydration completes. The optional
  /// [entryStateProvider] powers the platform entry doors (`/welcome`, `/intro`).
  static GoRouter create({
    required AuthProvider authProvider,
    OnboardingProvider? onboardingProvider,
    AdminReviewProvider? adminReviewProvider,
    EntryStateProvider? entryStateProvider,
    AppEnvironment environment = AppEnvironment.production,
  }) {
    final RouteGuard routeGuard = RouteGuard(
      authProvider: authProvider,
      onboardingProvider: onboardingProvider,
      adminReviewProvider: adminReviewProvider,
      entryStateProvider: entryStateProvider,
      environment: environment,
    );

    return GoRouter(
      initialLocation: EntryPlatform.isWeb
          ? RoutePaths.welcome
          : RoutePaths.home,
      refreshListenable: Listenable.merge(<Listenable>[
        authProvider,
        ?onboardingProvider,
        ?adminReviewProvider,
        ?entryStateProvider,
      ]),
      redirect: (BuildContext context, GoRouterState state) =>
          routeGuard.redirectResolver(state.matchedLocation),
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: RoutePaths.welcome,
          name: RouteNames.welcome,
          builder: (BuildContext context, GoRouterState state) =>
              const WelcomeScreen(),
        ),
        GoRoute(
          path: RoutePaths.about,
          name: RouteNames.about,
          builder: (BuildContext context, GoRouterState state) =>
              const AboutScreen(),
        ),
        GoRoute(
          path: RoutePaths.howItWorks,
          name: RouteNames.howItWorks,
          builder: (BuildContext context, GoRouterState state) =>
              const HowItWorksScreen(),
        ),
        GoRoute(
          path: RoutePaths.features,
          name: RouteNames.features,
          builder: (BuildContext context, GoRouterState state) =>
              const FeaturesScreen(),
        ),
        GoRoute(
          path: RoutePaths.pricing,
          name: RouteNames.pricing,
          builder: (BuildContext context, GoRouterState state) =>
              const PricingScreen(),
        ),
        GoRoute(
          path: RoutePaths.security,
          name: RouteNames.security,
          builder: (BuildContext context, GoRouterState state) =>
              const SecurityScreen(),
        ),
        GoRoute(
          path: RoutePaths.contact,
          name: RouteNames.contact,
          builder: (BuildContext context, GoRouterState state) =>
              const ContactScreen(),
        ),
        GoRoute(
          path: RoutePaths.help,
          name: RouteNames.help,
          builder: (BuildContext context, GoRouterState state) =>
              const HelpScreen(),
        ),
        GoRoute(
          path: RoutePaths.intro,
          name: RouteNames.intro,
          builder: (BuildContext context, GoRouterState state) =>
              const IntroScreen(),
        ),
        GoRoute(
          path: RoutePaths.login,
          name: RouteNames.login,
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
        GoRoute(
          path: RoutePaths.signup,
          name: RouteNames.signup,
          builder: (BuildContext context, GoRouterState state) =>
              const RegisterScreen(),
        ),
        GoRoute(
          path: RoutePaths.authConfirmation,
          name: RouteNames.authConfirmation,
          builder: (BuildContext context, GoRouterState state) =>
              AuthConfirmationGateScreen(
                email: state.uri.queryParameters['email'],
                next: state.uri.queryParameters['next'],
                mode: state.uri.queryParameters['mode'],
              ),
        ),
        GoRoute(
          path: RoutePaths.forgotPassword,
          name: RouteNames.forgotPassword,
          builder: (BuildContext context, GoRouterState state) =>
              const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: RoutePaths.resetPassword,
          name: RouteNames.resetPassword,
          builder: (BuildContext context, GoRouterState state) =>
              const ResetPasswordScreen(),
        ),
        GoRoute(
          path: RoutePaths.profile,
          name: RouteNames.profile,
          builder: (BuildContext context, GoRouterState state) =>
              const ProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const DashboardSettingsScreen(),
        ),
        GoRoute(
          path: RoutePaths.publicProfileRoute,
          name: RouteNames.publicProfile,
          builder: (BuildContext context, GoRouterState state) =>
              ProfessionalProfileScreen(
                profileId: state.pathParameters['id'] ?? '',
                routeSlug: state.pathParameters['slug'],
              ),
        ),
        GoRoute(
          path: RoutePaths.publicStoreRoute,
          name: RouteNames.publicStore,
          builder: (BuildContext context, GoRouterState state) =>
              const StoreScreen(),
        ),
        GoRoute(
          path: RoutePaths.verificationIdentity,
          name: RouteNames.verificationIdentity,
          builder: (BuildContext context, GoRouterState state) =>
              const IdentityDocumentUploadScreen(),
        ),
        GoRoute(
          path: RoutePaths.verificationStatus,
          name: RouteNames.verificationStatus,
          builder: (BuildContext context, GoRouterState state) =>
              const VerificationStatusScreen(),
        ),
        GoRoute(
          path: RoutePaths.tradeProofUpload,
          name: RouteNames.tradeProofUpload,
          builder: (BuildContext context, GoRouterState state) =>
              const TradeProofUploadScreen(),
        ),
        GoRoute(
          path: RoutePaths.tradeVerificationStatus,
          name: RouteNames.tradeVerificationStatus,
          builder: (BuildContext context, GoRouterState state) =>
              const TradeVerificationStatusScreen(),
        ),
        // Super Admin shell (narrow nav + workspace). Keeps legacy
        // review-queue paths while introducing /admin/dashboard landing.
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) =>
              SuperAdminShell(child: child),
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.adminRoot,
              redirect: (BuildContext context, GoRouterState state) =>
                  RoutePaths.adminDashboard,
            ),
            GoRoute(
              path: RoutePaths.adminDashboard,
              name: RouteNames.adminDashboard,
              builder: (BuildContext context, GoRouterState state) =>
                  const AdminDashboardScreen(),
            ),
            GoRoute(
              path: RoutePaths.adminReviewQueue,
              name: RouteNames.adminReviewQueue,
              builder: (BuildContext context, GoRouterState state) =>
                  const AdminReviewQueueScreen(),
            ),
            // Alias so nav can use Verification & Approvals name.
            GoRoute(
              path: '/admin/verifications',
              redirect: (BuildContext context, GoRouterState state) =>
                  RoutePaths.adminReviewQueue,
            ),
            GoRoute(
              path: RoutePaths.adminReviewDetail,
              name: RouteNames.adminReviewDetail,
              builder: (BuildContext context, GoRouterState state) =>
                  AdminReviewDetailScreen(
                    submissionId: state.pathParameters['submissionId'] ?? '',
                  ),
            ),
            GoRoute(
              path: RoutePaths.adminManageUsers,
              name: RouteNames.adminManageUsers,
              builder: (BuildContext context, GoRouterState state) =>
                  const ManageUserScreen(),
            ),
            GoRoute(
              path: RoutePaths.adminUsersProfessionals,
              name: RouteNames.adminManageUsersProfessionals,
              builder: (BuildContext context, GoRouterState state) =>
                  const ManageUserScreen(capability: 'professional'),
            ),
            GoRoute(
              path: RoutePaths.adminUsersClients,
              name: RouteNames.adminManageUsersClients,
              builder: (BuildContext context, GoRouterState state) =>
                  const ManageUserScreen(capability: 'client'),
            ),
            GoRoute(
              path: RoutePaths.adminManageUserDetail,
              name: RouteNames.adminManageUserDetail,
              builder: (BuildContext context, GoRouterState state) =>
                  ManageUserDetailScreen(
                    userId: state.pathParameters['userId'] ?? '',
                  ),
            ),
            GoRoute(
              path: RoutePaths.adminJobs,
              name: RouteNames.adminJobs,
              builder: (BuildContext context, GoRouterState state) =>
                  const AdminJobsScreen(),
            ),
          ],
        ),
        // Role-aware dashboard shell (capability-filtered nav + workspace).
        // Static segments (`new`) precede `:id` so literal matching wins.
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) =>
              HivorrDashboardShell(child: child),
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.dashboard,
              name: RouteNames.dashboard,
              builder: (BuildContext context, GoRouterState state) =>
                  const DashboardOverviewScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardJobs,
              name: RouteNames.dashboardJobs,
              builder: (BuildContext context, GoRouterState state) =>
                  const MyJobsScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardJobNew,
              name: RouteNames.dashboardJobNew,
              builder: (BuildContext context, GoRouterState state) =>
                  const JobFormScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardJobDetailRoute,
              name: RouteNames.dashboardJobDetail,
              builder: (BuildContext context, GoRouterState state) =>
                  JobDetailScreen(jobId: state.pathParameters['id'] ?? ''),
            ),
            GoRoute(
              path: RoutePaths.dashboardJobEditRoute,
              name: RouteNames.dashboardJobEdit,
              builder: (BuildContext context, GoRouterState state) =>
                  JobFormScreen(jobId: state.pathParameters['id']),
            ),
            GoRoute(
              path: RoutePaths.dashboardOpportunities,
              name: RouteNames.dashboardOpportunities,
              builder: (BuildContext context, GoRouterState state) =>
                  const OpportunitiesScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardApplications,
              name: RouteNames.dashboardApplications,
              builder: (BuildContext context, GoRouterState state) =>
                  const MyApplicationsScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardHires,
              name: RouteNames.dashboardHires,
              builder: (BuildContext context, GoRouterState state) =>
                  HiresScreen(
                    role: state.uri.queryParameters['role'] ?? 'client',
                  ),
            ),
            GoRoute(
              path: RoutePaths.dashboardHireDetailRoute,
              name: RouteNames.dashboardHireDetail,
              builder: (BuildContext context, GoRouterState state) =>
                  HireDetailScreen(hireId: state.pathParameters['id'] ?? ''),
            ),
            GoRoute(
              path: RoutePaths.dashboardMessages,
              name: RouteNames.dashboardMessages,
              builder: (BuildContext context, GoRouterState state) =>
                  const MessagesScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardMessageThreadRoute,
              name: RouteNames.dashboardMessageThread,
              builder: (BuildContext context, GoRouterState state) =>
                  ConversationScreen(
                    conversationId: state.pathParameters['id'] ?? '',
                  ),
            ),
            GoRoute(
              path: RoutePaths.dashboardNotifications,
              name: RouteNames.dashboardNotifications,
              builder: (BuildContext context, GoRouterState state) =>
                  const NotificationsScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardPayments,
              name: RouteNames.dashboardPayments,
              builder: (BuildContext context, GoRouterState state) =>
                  const PaymentsScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardEarnings,
              name: RouteNames.dashboardEarnings,
              builder: (BuildContext context, GoRouterState state) =>
                  const EarningsScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardAccount,
              name: RouteNames.dashboardAccount,
              builder: (BuildContext context, GoRouterState state) =>
                  const ProfileScreen(),
            ),
            GoRoute(
              path: RoutePaths.dashboardSettings,
              name: RouteNames.dashboardSettings,
              builder: (BuildContext context, GoRouterState state) =>
                  const DashboardSettingsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.kycStatus,
          name: RouteNames.kycStatus,
          builder: (BuildContext context, GoRouterState state) =>
              const KycStatusScreen(),
        ),
        GoRoute(
          path: RoutePaths.kycUpgrade,
          name: RouteNames.kycUpgrade,
          builder: (BuildContext context, GoRouterState state) =>
              const KycUpgradeScreen(),
        ),
        GoRoute(
          path: RoutePaths.finance,
          name: RouteNames.finance,
          builder: (BuildContext context, GoRouterState state) =>
              const FinancialProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.financeCreate,
          name: RouteNames.financeCreate,
          builder: (BuildContext context, GoRouterState state) =>
              const FinancialProfileCreationFlow(),
        ),
        GoRoute(
          path: RoutePaths.escrow,
          name: RouteNames.escrow,
          builder: (BuildContext context, GoRouterState state) =>
              const EscrowListScreen(),
        ),
        GoRoute(
          path: RoutePaths.escrowDetail,
          name: RouteNames.escrowDetail,
          builder: (BuildContext context, GoRouterState state) =>
              EscrowDetailScreen(escrowId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: RoutePaths.convert,
          name: RouteNames.convert,
          builder: (BuildContext context, GoRouterState state) =>
              const ConversionScreen(),
        ),
        GoRoute(
          path: RoutePaths.disputes,
          name: RouteNames.disputes,
          builder: (BuildContext context, GoRouterState state) =>
              const DisputeListScreen(),
        ),
        GoRoute(
          path: RoutePaths.disputesNew,
          name: RouteNames.disputesNew,
          builder: (BuildContext context, GoRouterState state) =>
              DisputeFilingScreen(
                escrowId: state.pathParameters['escrowId'] ?? '',
              ),
        ),
        GoRoute(
          path: RoutePaths.disputeDetail,
          name: RouteNames.disputeDetail,
          builder: (BuildContext context, GoRouterState state) =>
              DisputeDetailScreen(caseId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: RoutePaths.disputesEvidenceNew,
          name: RouteNames.disputesEvidenceNew,
          builder: (BuildContext context, GoRouterState state) =>
              DisputeEvidenceFormScreen(
                caseId: state.pathParameters['caseId'] ?? '',
              ),
        ),
        GoRoute(
          path: RoutePaths.serviceListingsMine,
          name: RouteNames.serviceListingsMine,
          builder: (BuildContext context, GoRouterState state) =>
              const MyListingsScreen(),
        ),
        GoRoute(
          path: RoutePaths.serviceListingNew,
          name: RouteNames.serviceListingNew,
          builder: (BuildContext context, GoRouterState state) =>
              const ServiceListingFormScreen(),
        ),
        GoRoute(
          path: RoutePaths.serviceListingEdit,
          name: RouteNames.serviceListingEdit,
          builder: (BuildContext context, GoRouterState state) =>
              ServiceListingFormScreen(listingId: state.pathParameters['id']),
        ),
        GoRoute(
          path: RoutePaths.serviceListingMedia,
          name: RouteNames.serviceListingMedia,
          builder: (BuildContext context, GoRouterState state) =>
              ServiceListingMediaScreen(
                listingId: state.pathParameters['id'] ?? '',
              ),
        ),
        GoRoute(
          path: RoutePaths.onboarding,
          redirect: (BuildContext context, GoRouterState state) =>
              RoutePaths.onboardingCapability,
        ),
        GoRoute(
          path: '/onboarding/:step',
          name: RouteNames.onboarding,
          builder: (BuildContext context, GoRouterState state) =>
              const OnboardingShellScreen(),
        ),
        GoRoute(
          path: '/onboarding/profession',
          redirect: (BuildContext context, GoRouterState state) =>
              RoutePaths.onboardingIndustry,
        ),
      ],
    );
  }
}

