import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/auth_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
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

  @override
  AuthStatus get status => _status;

  @override
  Stream<AuthStatus> get onStatusChanged => _controller.stream;

  final List<String> resetEmails = <String>[];
  final List<String> updatedPasswords = <String>[];

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
  Future<void> updatePassword(String newPassword) async {
    updatedPasswords.add(newPassword);
    final ApiException? error = failure;
    if (error != null) {
      throw error;
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
    MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
    ),
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

    testWidgets('Sign in is disabled until email and password are entered',
        (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.login),
        authProvider: provider,
      );

      HivorrButton button() => tester.widget<HivorrButton>(find.byType(HivorrButton));
      expect(button().onPressed, isNull);

      await enterField(tester, 'Email address', 'me@example.com');
      await tester.pump();
      expect(button().onPressed, isNull);

      await enterField(tester, 'Password', 'secret1');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('successful sign-in routes to the preserved ?next',
        (tester) async {
      final service = _ScriptedAuthService()
        ..setStatus(AuthStatus.authenticated);
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router =
          doorRouter(initialLocation: '${RoutePaths.login}?next=/p/acme/1');
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'secret1');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/p/acme/1');
    });

    testWidgets('failed sign-in surfaces the safe error and stays put',
        (tester) async {
      final service = _ScriptedAuthService()
        ..failure = const ApiException(
          kind: ApiExceptionKind.auth,
          message: 'Invalid email or password',
        );
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(initialLocation: RoutePaths.login);
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'wrong-pass');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(router.routerDelegate.state.matchedLocation, RoutePaths.login);
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
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('invalid input shows inline validation and does not submit',
        (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router = doorRouter(initialLocation: RoutePaths.signup);
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

      await enterField(tester, 'Email address', 'not-an-email');
      await enterField(tester, 'Password', '123');
      await enterField(tester, 'Confirm password', '123');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 6 characters.'), findsOneWidget);
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

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'abc123');
      await enterField(tester, 'Confirm password', 'abc999');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsWidgets);
    });

    testWidgets('successful registration routes to the preserved ?next',
        (tester) async {
      final service = _ScriptedAuthService()
        ..setStatus(AuthStatus.authenticated);
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router =
          doorRouter(initialLocation: '${RoutePaths.signup}?next=/p/acme/1');
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'abc123');
      await enterField(tester, 'Confirm password', 'abc123');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/p/acme/1');
    });

    testWidgets('awaiting-confirmation registration hands off to the gate',
        (tester) async {
      final service = _ScriptedAuthService()
        ..setStatus(AuthStatus.awaitingEmailConfirmation);
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      final GoRouter router =
          doorRouter(initialLocation: '${RoutePaths.signup}?next=/p/acme/1');
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

      await enterField(tester, 'Email address', 'me@example.com');
      await enterField(tester, 'Password', 'abc123');
      await enterField(tester, 'Confirm password', 'abc123');
      await tester.tap(find.text('Create account'));
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
        router.routerDelegate.state.uri.queryParameters['next'],
        '/p/acme/1',
      );
    });
  });

  group('AuthConfirmationGateScreen', () {
    testWidgets('shows the address and waits for confirmation', (tester) async {
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
      expect(find.text('Waiting for confirmation…'), findsOneWidget);
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
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

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
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, RoutePaths.login);
      expect(
        router.routerDelegate.state.uri.queryParameters['next'],
        '/p/acme/1',
      );
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('requests a recovery email and shows the neutral message',
        (tester) async {
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

    testWidgets('never leaks account existence, even on failure',
        (tester) async {
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
        find.text('If an account exists for that address, recovery '
            'instructions are on their way.'),
        findsOneWidget,
      );
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('renders and disables Update password until both fields match',
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
      HivorrButton button() => tester.widget<HivorrButton>(find.byType(HivorrButton));

      expect(button().onPressed, isNull);

      await enterField(tester, 'New password', 'abc123');
      await enterField(tester, 'Confirm new password', 'abc999');
      await tester.pump();
      expect(button().onPressed, isNull);
    });

    testWidgets('update records the password and confirms success',
        (tester) async {
      final service = _ScriptedAuthService();
      final provider = AuthProvider(service: service);
      addTearDown(provider.dispose);

      await pumpAuth(
        tester,
        router: doorRouter(initialLocation: RoutePaths.resetPassword),
        authProvider: provider,
      );

      await enterField(tester, 'New password', 'newpass1');
      await enterField(tester, 'Confirm new password', 'newpass1');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      expect(service.updatedPasswords, <String>['newpass1']);
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

      final GoRouter router =
          doorRouter(initialLocation: RoutePaths.resetPassword);
      await pumpAuth(
        tester,
        router: router,
        authProvider: provider,
      );

      await enterField(tester, 'New password', 'newpass1');
      await enterField(tester, 'Confirm new password', 'newpass1');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to sign in'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, RoutePaths.login);
    });
  });

  testWidgets('AuthErrorText renders the safe message in the error tone',
      (tester) async {
    await pumpTheme(
      tester,
      const AuthErrorText(message: 'Something went wrong'),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}