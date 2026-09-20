import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/auth_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/models/registration_identity.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/shared/validators/password_policy.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_auth.dart';
import '../../../support/harnesses/router_harness.dart';
import '../../../support/harnesses/widget_harness.dart';

/// Controllable [AuthService]: status can be scripted, and sign-in/sign-up
/// either succeed (reporting the current status) or throw the configured
/// [failure]. Password-reset seams record their arguments for assertions.
class _ScriptedAuthService extends FakeAuthService {
  _ScriptedAuthService({AuthStatus initialStatus = AuthStatus.unauthenticated})
    : _status = initialStatus {
    _controller = StreamController<AuthStatus>.broadcast();
  }

  AuthStatus _status;
  StreamController<AuthStatus> _controller = StreamController<AuthStatus>();

  ApiException? failure;

  /// Thrown specifically by [updatePassword] (recovery/update failures).
  ApiException? updateFailure;

  /// Scripted [AuthService.recoveryCallbackError] (failure at recovery-link
  /// exchange, surfaced at bootstrap).
  ApiException? recoveryCallbackErrorValue;

  @override
  AuthStatus get status => _status;

  @override
  ApiException? get recoveryCallbackError => recoveryCallbackErrorValue;

  @override
  Stream<AuthStatus> get onStatusChanged => _controller.stream;

  final List<String> resetEmails = <String>[];
  final List<String> updatedPasswords = <String>[];
  final List<String> otpEmails = <String>[];
  final List<bool> otpCreateFlags = <bool>[];
  final List<String> verifiedCodes = <String>[];

  /// Drives the provider's reported status and notifies listeners.
  void setStatus(AuthStatus next) {
    _status = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) =>
      _result(() => AuthResult(status: _status));

  @override
  Future<AuthResult> signUp(AuthCredentials credentials) =>
      _result(() => AuthResult(status: _status));

  @override
  Future<AuthResult> signUpWithIdentity(RegistrationIdentity identity) =>
      _result(() => AuthResult(status: _status));

  Future<AuthResult> _result(AuthResult Function() build) async {
    final ApiException? error = failure;
    if (error != null) {
      throw error;
    }
    return build();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetEmails.add(email);
    final ApiException? error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> sendEmailVerificationOtp(
    String email, {
    bool createIfMissing = false,
  }) async {
    otpEmails.add(email);
    otpCreateFlags.add(createIfMissing);
    final ApiException? error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
    String? newPassword,
  }) async {
    verifiedCodes.add(code);
    final ApiException? error = failure;
    if (error != null) {
      throw error;
    }
    setStatus(AuthStatus.authenticated);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatedPasswords.add(newPassword);
    final ApiException? error = updateFailure;
    if (error != null) {
      throw error;
    }
    final ApiException? generic = failure;
    if (generic != null) {
      throw generic;
    }
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

Future<void> pumpAuth(
  WidgetTester tester, {
  required GoRouter router,
  required AuthProvider authProvider,
  double width = 390,
}) async {
  await pumpScreen(
    tester,
    MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    width: width,
    height: 844,
  );
}

Future<void> enterField(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await tester.pump();
}

/// Fills the new required identity fields for registration restructuring.
Future<void> fillRegistrationIdentity(WidgetTester tester) async {
  await enterField(tester, 'First name', 'Jane');
  await enterField(tester, 'Last name', 'Doe');
  await enterField(tester, 'Display name', 'Jane D');
  await enterField(tester, 'Phone number', '+1 555 000 1234');
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders the sign-in form chrome', (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.login),
        authProvider: provider,
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('New here? Create your free account'), findsOneWidget);
    });

    testWidgets('Sign in is disabled until email and password are entered', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.login),
        authProvider: provider,
      );

      HivorrButton button() =>
          tester.widget<HivorrButton>(find.byType(HivorrButton));
      expect(button().onPressed, isNull);

      await enterField(tester, 'Email address', 'me@example.com');
      await tester.pump();
      expect(button().onPressed, isNull);

      await enterField(tester, 'Password', 'secret1');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('successful sign-in routes to the preserved ?next', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..setStatus(AuthStatus.authenticated);
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: '${RoutePaths.login}?next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'secret1');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/p/acme/1');
    });

    testWidgets('failed sign-in surfaces the safe error and stays put', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.auth,
          message: 'Invalid email or password',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(initialLocation: RoutePaths.login);
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'wrong-pass');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(router.routerDelegate.state.matchedLocation, RoutePaths.login);
    });

    testWidgets('failed sign-in with email_not_confirmed routes to the '
        'verification gate in resume mode', (tester) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.auth,
          message: 'Your email address has not been verified yet.',
          code: 'email_not_confirmed',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(initialLocation: RoutePaths.login);
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'any-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.state.matchedLocation,
        RoutePaths.authConfirmation,
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['email'],
        'me@example.com',
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['mode'],
        RoutePaths.authVerificationResumeMode,
      );
    });

    testWidgets('failed sign-in with email_not_verified routes to the '
        'verification gate in resume mode (parity)', (tester) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.auth,
          message: 'Your email address has not been verified yet.',
          code: 'email_not_verified',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(initialLocation: RoutePaths.login);
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'any-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.state.matchedLocation,
        RoutePaths.authConfirmation,
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['email'],
        'me@example.com',
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['mode'],
        RoutePaths.authVerificationResumeMode,
      );
    });
  });

  group('RegisterScreen', () {
    testWidgets('renders credentials-only registration form', (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.signup),
        authProvider: provider,
      );

      expect(find.text('Create your free account'), findsOneWidget);
      expect(find.text('First name'), findsOneWidget);
      expect(find.text('Last name'), findsOneWidget);
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('invalid input shows inline validation and does not submit', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(initialLocation: RoutePaths.signup);
      await pumpAuth(tester, router: router, authProvider: provider);

      await fillRegistrationIdentity(tester);
      await enterField(tester, 'Email address', 'not-an-email');
      await enterField(tester, 'Password', '123');
      await enterField(tester, 'Confirm password', '123');
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text(PasswordPolicy.supabase.invalidMessage), findsOneWidget);
      expect(router.routerDelegate.state.matchedLocation, RoutePaths.signup);
    });

    testWidgets('password mismatch blocks submission', (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.signup),
        authProvider: provider,
      );

      await fillRegistrationIdentity(tester);
      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'Abc123!9');
      await enterField(tester, 'Confirm password', 'Abc123!8');
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsWidgets);
    });

    testWidgets('successful registration routes to the preserved ?next', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..setStatus(AuthStatus.authenticated);
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: '${RoutePaths.signup}?next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await fillRegistrationIdentity(tester);
      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'Abc123!9');
      await enterField(tester, 'Confirm password', 'Abc123!9');
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/p/acme/1');
    });

    testWidgets('awaiting-confirmation registration hands off to the gate', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..setStatus(AuthStatus.awaitingEmailConfirmation);
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: '${RoutePaths.signup}?next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await fillRegistrationIdentity(tester);
      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'Abc123!9');
      await enterField(tester, 'Confirm password', 'Abc123!9');
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      // No redundant OTP re-send: the signup confirmation email already
      // carries the verification code, and an explicit /otp would trip the
      // send rate limit straight after signUp.
      expect(service.otpEmails, <String>[]);
      expect(service.otpCreateFlags, <bool>[]);
      expect(
        router.routerDelegate.state.matchedLocation,
        RoutePaths.authConfirmation,
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['email'],
        'me@example.com',
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['next'],
        '/p/acme/1',
      );
    });

    testWidgets('a user_already_exists error surfaces the message and Log In', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.conflict,
          message:
              'An account already exists with this email address. '
              'Please log in to continue.',
          code: 'user_already_exists',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: '${RoutePaths.signup}?next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await fillRegistrationIdentity(tester);
      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'Abc123!9');
      await enterField(tester, 'Confirm password', 'Abc123!9');
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'An account already exists with this email address. '
          'Please log in to continue.',
        ),
        findsOneWidget,
      );
      expect(service.otpEmails, isEmpty);
      expect(router.routerDelegate.state.matchedLocation, RoutePaths.signup);

      await tester.ensureVisible(find.text('Log In'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, RoutePaths.login);
      expect(
        router.routerDelegate.state.uri.queryParameters['next'],
        '/p/acme/1',
      );
    });

    testWidgets('a user_already_exists error offers Verify email to resume '
        'verification without a duplicate account', (tester) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.conflict,
          message:
              'An account already exists with this email address. '
              'Please log in to continue.',
          code: 'user_already_exists',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: '${RoutePaths.signup}?next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await fillRegistrationIdentity(tester);
      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'Abc123!9');
      await enterField(tester, 'Confirm password', 'Abc123!9');
      await tester.ensureVisible(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      // No OTP is sent while submitting the duplicate; no account is created.
      expect(service.otpEmails, isEmpty);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Verify email'), findsOneWidget);

      await tester.ensureVisible(find.text('Verify email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.state.matchedLocation,
        RoutePaths.authConfirmation,
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['email'],
        'me@example.com',
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['mode'],
        RoutePaths.authVerificationResumeMode,
      );
      expect(
        router.routerDelegate.state.uri.queryParameters['next'],
        '/p/acme/1',
      );
      // Resume mode issues a fresh code for the existing identity only —
      // never `shouldCreateUser: true`.
      expect(service.otpEmails, <String>['me@example.com']);
      expect(service.otpCreateFlags, <bool>[false]);
    });

    testWidgets('password checklist and strength update as user types', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.signup),
        authProvider: provider,
      );

      // Empty — no strength indicator, all requirements unsatisfied
      expect(find.text('Password strength:'), findsNothing);

      await enterField(tester, 'Password', 'hello');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Weak'), findsOneWidget);
      expect(find.text('Lowercase letter'), findsOneWidget);
      expect(find.text('Uppercase letter'), findsOneWidget);

      await enterField(tester, 'Password', 'Hello');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Medium'), findsOneWidget);

      await enterField(tester, 'Password', 'Hello123');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Medium'), findsOneWidget);

      await enterField(tester, 'Password', 'Hello123!');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Strong'), findsOneWidget);
    });

    testWidgets('confirm field shows match indicator in real time', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.signup),
        authProvider: provider,
      );

      await enterField(tester, 'Password', 'Abc123!9');
      await enterField(tester, 'Confirm password', 'Abc123!8');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);

      await enterField(tester, 'Confirm password', 'Abc123!9');
      await tester.pumpAndSettle();
      expect(find.text('Passwords match'), findsOneWidget);
    });
  });

  group('AuthConfirmationGateScreen', () {
    testWidgets('shows the address and an OTP entry for verification', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(
          initialLocation:
              '${RoutePaths.authConfirmation}?email=me@example.com&next=/p/acme/1',
        ),
        authProvider: provider,
      );

      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.textContaining('me@example.com'), findsOneWidget);
      expect(
        find.textContaining('Enter the 6-digit code sent to'),
        findsOneWidget,
      );
      expect(find.text('Verification code'), findsOneWidget);
      expect(find.text('Verify code'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
    });

    testWidgets('verifying the code activates the session and continues', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation:
            '${RoutePaths.authConfirmation}?email=me@example.com&next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'Verification code', '123456');
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();

      expect(service.verifiedCodes, <String>['123456']);
      expect(router.routerDelegate.state.matchedLocation, '/p/acme/1');
    });

    testWidgets('auto-continues to the preserved destination once the session '
        'arrives', (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation:
            '${RoutePaths.authConfirmation}?email=me@example.com&next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      service.setStatus(AuthStatus.authenticated);
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/p/acme/1');
    });

    testWidgets('back to sign in carries the preserved ?next', (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation:
            '${RoutePaths.authConfirmation}?email=me@example.com&next=/p/acme/1',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, RoutePaths.login);
      expect(
        router.routerDelegate.state.uri.queryParameters['next'],
        '/p/acme/1',
      );
    });

    testWidgets('resume mode issues a fresh code on entry', (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(
          initialLocation:
              '${RoutePaths.authConfirmation}?email=me@example.com'
              '&mode=${RoutePaths.authVerificationResumeMode}&next=/p/acme/1',
        ),
        authProvider: provider,
      );
      await tester.pumpAndSettle();

      expect(service.otpEmails, <String>['me@example.com']);
      expect(service.otpCreateFlags, <bool>[false]);
    });

    testWidgets('resend arms a cooldown and disables until it elapses', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(
          initialLocation:
              '${RoutePaths.authConfirmation}?email=me@example.com',
        ),
        authProvider: provider,
      );

      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();

      expect(service.otpEmails.length, 1);
      expect(find.text('Resend code in 01:00'), findsOneWidget);
      // The cooldown label disables the resend action.
      final TextButton button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Resend code in 01:00'),
      );
      expect(button.onPressed, isNull);

      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Resend code'), findsOneWidget);
    });

    testWidgets('an invalid code surfaces the specific message', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.auth,
          message:
              'The code you entered is incorrect. Please check the code and try again.',
          code: 'invalid_otp',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: '${RoutePaths.authConfirmation}?email=me@example.com',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'Verification code', '000000');
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The code you entered is incorrect. Please check the code and try again.',
        ),
        findsOneWidget,
      );
      expect(
        router.routerDelegate.state.matchedLocation,
        RoutePaths.authConfirmation,
      );
    });

    testWidgets('an otp_expired error (wrong/expired/used) surfaces the '
        'combined incorrect-or-expired message and stays on the gate', (
      tester,
    ) async {
      // Regression for “wrong OTP showed expired”: Supabase conflates wrong,
      // expired and already-used into `otp_expired`. The gate must show the
      // combined copy and must not auto-resend or navigate away.
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.validation,
          message:
              'The code you entered is incorrect or has expired. Please check the code and try again. If it has expired, request a new code.',
          code: 'otp_expired',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: '${RoutePaths.authConfirmation}?email=me@example.com',
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'Verification code', '000000');
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The code you entered is incorrect or has expired. Please check the code and try again. If it has expired, request a new code.',
        ),
        findsOneWidget,
      );
      // Must remain on the OTP screen (no auto-advance, no auto resend).
      expect(
        router.routerDelegate.state.matchedLocation,
        RoutePaths.authConfirmation,
      );
      expect(service.otpEmails, isEmpty);
      expect(find.text('Resend code'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('requests a recovery email and shows the neutral message', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.forgotPassword),
        authProvider: provider,
      );

      expect(find.text('Reset your password'), findsOneWidget);

      await enterField(tester, 'Email address', 'me@example.com');
      await tester.tap(find.text('Send recovery email'));
      await tester.pumpAndSettle();

      expect(service.resetEmails, <String>['me@example.com']);
      expect(
        find.textContaining('If an account exists for that address'),
        findsOneWidget,
      );
    });

    testWidgets('never leaks account existence, even on failure', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'No account found',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.forgotPassword),
        authProvider: provider,
      );

      await enterField(tester, 'Email address', 'me@example.com');
      await tester.tap(find.text('Send recovery email'));
      await tester.pumpAndSettle();

      expect(find.text('No account found'), findsNothing);
      expect(
        find.text(
          'If an account exists for that address, recovery '
          'instructions are on their way.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets(
      'renders and disables Update password until both fields match',
      (tester) async {
        final service = _ScriptedAuthService();
        final provider = AuthProvider(service: service);
        addTearDown(provider.dispose);

        await pumpAuth(
          tester,
          router: doorRouter(initialLocation: RoutePaths.resetPassword),
          authProvider: provider,
        );

        expect(find.text('Set a new password'), findsOneWidget);
        HivorrButton button() =>
            tester.widget<HivorrButton>(find.byType(HivorrButton));

        expect(button().onPressed, isNull);

        await enterField(tester, 'New password', 'Newpass1!');
        await enterField(tester, 'Confirm new password', 'Newpass2!');
        await tester.pump();
        expect(button().onPressed, isNull);
      },
    );

    testWidgets('update records the password and confirms success', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.resetPassword),
        authProvider: provider,
      );

      await enterField(tester, 'New password', 'Newpass1!');
      await enterField(tester, 'Confirm new password', 'Newpass1!');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      expect(service.updatedPasswords, <String>['Newpass1!']);
      expect(
        find.text('Your password has been updated. You can now sign in.'),
        findsOneWidget,
      );
      expect(find.text('Go to sign in'), findsOneWidget);
    });

    testWidgets('Go to sign in navigates to the login door', (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: RoutePaths.resetPassword,
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'New password', 'Newpass1!');
      await enterField(tester, 'Confirm new password', 'Newpass1!');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to sign in'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, RoutePaths.login);
    });

    testWidgets('button stays disabled when password fails the policy', (
      tester,
    ) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.resetPassword),
        authProvider: provider,
      );

      HivorrButton button() =>
          tester.widget<HivorrButton>(find.byType(HivorrButton));

      // Password too short / missing classes — even when fields match
      await enterField(tester, 'New password', 'short');
      await enterField(tester, 'Confirm new password', 'short');
      await tester.pump();
      expect(button().onPressed, isNull);

      // Still invalid — no uppercase / symbol
      await enterField(tester, 'New password', 'newpass1');
      await enterField(tester, 'Confirm new password', 'newpass1');
      await tester.pump();
      expect(button().onPressed, isNull);

      // Policy-compliant → button enabled
      await enterField(tester, 'New password', 'Newpass1!');
      await enterField(tester, 'Confirm new password', 'Newpass1!');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets(
      'an invalid/expired link shows recovery guidance, not success',
      (tester) async {
        final service = _ScriptedAuthService()
          ..updateFailure = const ApiException(
            kind: ApiExceptionKind.validation,
            message:
                'This reset link is invalid or has expired. '
                'Request a new one.',
            code: 'invalid_grant',
          );
        final provider = AuthProvider(service: service);
        addTearDown(provider.dispose);

        await pumpAuth(
          tester,
          router: doorRouter(initialLocation: RoutePaths.resetPassword),
          authProvider: provider,
        );

        await enterField(tester, 'New password', 'Newpass1!');
        await enterField(tester, 'Confirm new password', 'Newpass1!');
        await tester.tap(find.text('Update password'));
        await tester.pumpAndSettle();

        expect(find.textContaining('invalid or has expired'), findsOneWidget);
        expect(find.text('Request a new link'), findsOneWidget);
        expect(
          find.text('Your password has been updated. You can now sign in.'),
          findsNothing,
        );
      },
    );

    testWidgets('Request a new link navigates to the forgot-password door', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..updateFailure = const ApiException(
          kind: ApiExceptionKind.validation,
          message:
              'This reset link is invalid or has expired. '
              'Request a new one.',
          code: 'invalid_grant',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(
        initialLocation: RoutePaths.resetPassword,
      );
      await pumpAuth(tester, router: router, authProvider: provider);

      await enterField(tester, 'New password', 'Newpass1!');
      await enterField(tester, 'Confirm new password', 'Newpass1!');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request a new link'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.state.matchedLocation,
        RoutePaths.forgotPassword,
      );
      expect(find.text('Reset your password'), findsOneWidget);
    });

    testWidgets('a failed recovery callback shows the expired-link state', (
      tester,
    ) async {
      final service = _ScriptedAuthService()
        ..recoveryCallbackErrorValue = const ApiException(
          kind: ApiExceptionKind.validation,
          message:
              'This reset link is invalid or has expired. '
              'Request a new one.',
          code: 'invalid_grant',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.resetPassword),
        authProvider: provider,
      );

      expect(find.textContaining('invalid or has expired'), findsOneWidget);
      expect(find.text('Request a new link'), findsOneWidget);
      // No password form behind a broken link.
      expect(find.text('New password'), findsNothing);
      expect(find.text('Update password'), findsNothing);
    });
  });

  testWidgets('AuthErrorText renders the safe message in the error tone', (
    tester,
  ) async {
    await pumpTheme(
      tester,
      const AuthErrorText(message: 'Something went wrong'),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
