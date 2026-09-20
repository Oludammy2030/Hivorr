import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/services/supabase_auth_service.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_fakes.dart';

AuthService buildService({
  required FakeGoTrueClient authClient,
  SupabaseClient? supabaseClient,
  bool recordProvisioning = false,
  AuthConfig? config,
  Uri? callbackUri,
}) {
  final Uri Function()? resolver = callbackUri == null
      ? null
      : () => callbackUri;
  if (recordProvisioning) {
    return FakeSupabaseAuthService(
      authClient: authClient,
      supabaseClient: supabaseClient ?? FakeSupabaseClient(),
      config: config ?? const AuthConfig(),
      callbackUriResolver: resolver,
    );
  }
  return SupabaseAuthService(
    authClient: authClient,
    supabaseClient: supabaseClient ?? FakeSupabaseClient(),
    config: config ?? const AuthConfig(),
    callbackUriResolver: resolver,
  );
}

void main() {
  group('SupabaseAuthService', () {
    late FakeGoTrueClient authClient;

    setUp(() => authClient = FakeGoTrueClient());
    tearDown(() async => authClient.close());

    test('signUp returns authenticated when a session is issued', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.returnSessionOnSignUp = true;

      final AuthResult result = await service.signUp(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(result.status, AuthStatus.authenticated);
      expect(result.session?.entityId, 'u1');
      expect(service.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      expect(service.isSignedIn, isTrue);
      await service.dispose();
    });

    test('signUp returns awaitingEmailConfirmation when no session', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.returnSessionOnSignUp = false;

      final AuthResult result = await service.signUp(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(result.status, AuthStatus.awaitingEmailConfirmation);
      expect(service.status, AuthStatus.awaitingEmailConfirmation);
      expect(service.isSignedIn, isFalse);
      await service.dispose();
    });

    test(
      'sendEmailVerificationOtp requests the code and awaits confirmation',
      () async {
        final AuthService service = buildService(authClient: authClient);

        await service.sendEmailVerificationOtp('a@b.com');

        expect(authClient.otpCallCount, 1);
        expect(authClient.otpEmail, 'a@b.com');
        expect(authClient.otpShouldCreateUser, isFalse);
        expect(service.status, AuthStatus.awaitingEmailConfirmation);
        expect(service.isSignedIn, isFalse);
        await service.dispose();
      },
    );

    test(
      'sendEmailVerificationOtp only creates when explicitly requested',
      () async {
        final AuthService service = buildService(authClient: authClient);

        await service.sendEmailVerificationOtp(
          'a@b.com',
          createIfMissing: true,
        );

        expect(authClient.otpShouldCreateUser, isTrue);
        await service.dispose();
      },
    );

    test('verifyEmailOtp activates the session on a valid code', () async {
      final AuthService service = buildService(authClient: authClient);

      await service.verifyEmailOtp(email: 'a@b.com', code: '123456');

      expect(authClient.verifyCallCount, 1);
      expect(authClient.verifiedType, OtpType.email);
      expect(authClient.verifiedToken, '123456');
      expect(service.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      await service.dispose();
    });

    test(
      'verifyEmailOtp optionally assigns a password after the code',
      () async {
        final AuthService service = buildService(authClient: authClient);

        await service.verifyEmailOtp(
          email: 'a@b.com',
          code: '123456',
          newPassword: 'separate-password',
        );

        expect(authClient.updatedPassword, 'separate-password');
        expect(service.status, AuthStatus.authenticated);
        await service.dispose();
      },
    );

    test(
      'verifyEmailOtp without a password keeps the account credentials',
      () async {
        final AuthService service = buildService(authClient: authClient);

        await service.verifyEmailOtp(email: 'a@b.com', code: '123456');

        expect(authClient.updatedPassword, isNull);
        expect(service.status, AuthStatus.authenticated);
        await service.dispose();
      },
    );

    test(
      'verifyEmailOtp without a session stays awaiting confirmation',
      () async {
        final AuthService service = buildService(authClient: authClient);
        authClient.returnSessionOnVerify = false;

        await service.verifyEmailOtp(email: 'a@b.com', code: '000000');

        expect(service.status, AuthStatus.awaitingEmailConfirmation);
        expect(service.isSignedIn, isFalse);
        await service.dispose();
      },
    );

    test('an invalid code surfaces a typed ApiException', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'Token has expired or is invalid',
        statusCode: '400',
      );

      expect(
        () => service.verifyEmailOtp(email: 'a@b.com', code: 'wrong'),
        throwsA(isA<ApiException>()),
      );
      expect(service.status, AuthStatus.initial);
      await service.dispose();
    });

    test('user_already_exists surfaces a typed ApiException', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'User already registered',
        statusCode: '422',
        code: 'user_already_exists',
      );

      late final ApiException error;
      try {
        await service.signUp(
          AuthCredentials(email: 'a@b.com', password: 'password'),
        );
        fail('Expected ApiException');
      } on Object catch (e) {
        error = e as ApiException;
      }

      expect(error.code, 'user_already_exists');
      expect(error.kind, ApiExceptionKind.conflict);
      await service.dispose();
    });

    test('email_not_confirmed surfaces a typed ApiException', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'Email not confirmed',
        statusCode: '400',
        code: 'email_not_confirmed',
      );

      late final ApiException error;
      try {
        await service.signIn(
          AuthCredentials(email: 'a@b.com', password: 'password'),
        );
        fail('Expected ApiException');
      } on Object catch (e) {
        error = e as ApiException;
      }

      expect(error.code, 'email_not_confirmed');
      expect(error.message, 'Your email address has not been verified yet.');
      await service.dispose();
    });

    test('email_not_verified maps like email_not_confirmed', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'Email not verified',
        statusCode: '400',
        code: 'email_not_verified',
      );

      late final ApiException error;
      try {
        await service.signIn(
          AuthCredentials(email: 'a@b.com', password: 'password'),
        );
        fail('Expected ApiException');
      } on Object catch (e) {
        error = e as ApiException;
      }

      expect(error.code, 'email_not_verified');
      expect(error.message, 'Your email address has not been verified yet.');
      expect(error.kind, ApiExceptionKind.auth);
      await service.dispose();
    });

    test('a bare 400 without a code stays generic (no enumeration)', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );

      late final ApiException error;
      try {
        await service.signIn(
          AuthCredentials(email: 'a@b.com', password: 'wrong'),
        );
        fail('Expected ApiException');
      } on Object catch (e) {
        error = e as ApiException;
      }

      // Only the HTTP status flows through (transport-only code); no semantic
      // gotrue code leaks the verification state to the login form.
      expect(error.code, '400');
      expect(error.message, 'Validation failed.');
      await service.dispose();
    });

    test('invalid_otp surfaces a typed ApiException', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_otp',
      );

      late final ApiException error;
      try {
        await service.verifyEmailOtp(email: 'a@b.com', code: 'wrong');
        fail('Expected ApiException');
      } on Object catch (e) {
        error = e as ApiException;
      }

      expect(error.code, 'invalid_otp');
      expect(
        error.message,
        'The code you entered is incorrect. Please check the code and try again.',
      );
      await service.dispose();
    });

    test('otp_expired surfaces the combined incorrect-or-expired message '
        '(server conflates invalid/expired/used)', () async {
      final AuthService service = buildService(authClient: authClient);
      // Supabase Auth returns `otp_expired` for wrong, expired and
      // already-used OTPs with message "Token has expired or is invalid"
      // (verify.go: verifyUserAndToken / verifyTokenHash). The service must
      // not claim pure expiry for a typo.
      authClient.nextError = const AuthException(
        'Token has expired or is invalid',
        statusCode: '403',
        code: 'otp_expired',
      );

      late final ApiException error;
      try {
        await service.verifyEmailOtp(email: 'a@b.com', code: 'wrong');
        fail('Expected ApiException');
      } on Object catch (e) {
        error = e as ApiException;
      }

      expect(error.code, 'otp_expired');
      expect(error.kind, ApiExceptionKind.validation);
      // Regression guard: must NOT be the old pure-expiry copy.
      expect(error.message, isNot('That code has expired. Request a new one.'));
      expect(
        error.message,
        'The code you entered is incorrect or has expired. Please check the code and try again. If it has expired, request a new code.',
      );
      // Incorrect OTP must not change auth state or create a session.
      expect(service.status, AuthStatus.initial);
      expect(service.isSignedIn, isFalse);
      expect(service.currentSession, isNull);
      await service.dispose();
    });

    test(
      'otp_expired for a truly expired link also yields the combined message',
      () async {
        final AuthService service = buildService(authClient: authClient);
        authClient.nextError = const AuthException(
          'Email link is invalid or has expired',
          statusCode: '403',
          code: 'otp_expired',
        );

        late final ApiException error;
        try {
          await service.verifyEmailOtp(email: 'a@b.com', code: '000000');
          fail('Expected ApiException');
        } on Object catch (e) {
          error = e as ApiException;
        }

        expect(error.code, 'otp_expired');
        expect(
          error.message,
          'The code you entered is incorrect or has expired. Please check the code and try again. If it has expired, request a new code.',
        );
        await service.dispose();
      },
    );

    test('isEmailConfirmed is true when emailConfirmedAt is set', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.emailConfirmedInSession = true;

      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(service.currentSession?.isEmailConfirmed, isTrue);
      await service.dispose();
    });

    test('isEmailConfirmed is false when emailConfirmedAt is absent', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.emailConfirmedInSession = false;

      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(service.currentSession?.isEmailConfirmed, isFalse);
      await service.dispose();
    });

    test('signIn returns authenticated and exposes the entity id', () async {
      final AuthService service = buildService(authClient: authClient);

      final AuthResult result = await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(result.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      expect(service.currentSession?.entityId, 'u1');
      await service.dispose();
    });

    test('signOut transitions to unauthenticated', () async {
      final AuthService service = buildService(authClient: authClient);
      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );
      expect(service.isSignedIn, isTrue);

      await service.signOut();

      expect(service.status, AuthStatus.unauthenticated);
      expect(service.currentEntityId, isNull);
      expect(service.isSignedIn, isFalse);
      await service.dispose();
    });

    test('initialize restores a persisted session as authenticated', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.seedSession(fakeSession('u1'));

      await service.initialize();

      expect(service.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      await service.dispose();
    });

    test('initialize with no session yields unauthenticated', () async {
      final AuthService service = buildService(authClient: authClient);

      await service.initialize();

      expect(service.status, AuthStatus.unauthenticated);
      await service.dispose();
    });

    test('invalid credentials surface a typed ApiException', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );

      expect(
        () => service.signIn(
          AuthCredentials(email: 'a@b.com', password: 'wrong'),
        ),
        throwsA(isA<ApiException>()),
      );
      await service.dispose();
    });

    test('onAuthStateChange signedIn drives authenticated state', () async {
      final AuthService service = buildService(authClient: authClient);
      await service.initialize();
      expect(service.status, AuthStatus.unauthenticated);

      authClient.emit(AuthChangeEvent.signedIn, fakeSession('u1'));
      await pumpEventQueue();

      expect(service.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      await service.dispose();
    });

    test('onAuthStateChange signedOut drives unauthenticated state', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.seedSession(fakeSession('u1'));
      await service.initialize();
      expect(service.status, AuthStatus.authenticated);

      authClient.emit(AuthChangeEvent.signedOut);
      await pumpEventQueue();

      expect(service.status, AuthStatus.unauthenticated);
      await service.dispose();
    });

    test('ensureEntityExists is idempotent per signed-in user', () async {
      final FakeSupabaseAuthService service =
          buildService(authClient: authClient, recordProvisioning: true)
              as FakeSupabaseAuthService;

      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );
      await pumpEventQueue();
      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );
      await pumpEventQueue();

      expect(service.provisionCallCount, 1);
      await service.dispose();
    });

    group('password recovery', () {
      test(
        'requestPasswordReset forwards the configured redirect URL',
        () async {
          final AuthService service = buildService(
            authClient: authClient,
            config: const AuthConfig(
              recoveryRedirectBase: 'https://staging.hivorr.com',
            ),
          );

          await service.requestPasswordReset('a@b.com');

          expect(authClient.resetCallCount, 1);
          expect(authClient.resetEmail, 'a@b.com');
          expect(
            authClient.resetRedirectTo,
            'https://staging.hivorr.com/reset-password',
          );
          await service.dispose();
        },
      );

      test('a recovery callback exchange drives AuthStatus.recovery', () async {
        final AuthService service = buildService(
          authClient: authClient,
          callbackUri: Uri.parse(
            'http://localhost:8080/reset-password?code=reset-code',
          ),
        );

        await service.initialize();

        expect(authClient.exchangeCallCount, 1);
        expect(authClient.exchangedCode, 'reset-code');
        expect(service.status, AuthStatus.recovery);
        expect(service.isRecoverySession, isTrue);
        expect(service.isSignedIn, isFalse);
        expect(service.currentSession?.entityId, 'u1');
        expect(service.recoveryCallbackError, isNull);
        await service.dispose();
      });

      test(
        'an unverified email keeps the recovery session (orthogonal gate)',
        () async {
          final AuthService service = buildService(
            authClient: authClient,
            callbackUri: Uri.parse(
              'http://localhost:8080/reset-password?code=c',
            ),
          );
          authClient.emailConfirmedInSession = false;

          await service.initialize();

          expect(service.status, AuthStatus.recovery);
          expect(service.currentSession?.isEmailConfirmed, isFalse);
          await service.dispose();
        },
      );

      test('a failed exchange surfaces recoveryCallbackError and stays '
          'unauthenticated', () async {
        final AuthService service = buildService(
          authClient: authClient,
          callbackUri: Uri.parse('http://localhost:8080/reset-password?code=c'),
        );
        authClient.exchangeError = const AuthException(
          'Code verifier could not be found in local storage.',
        );

        await service.initialize();

        expect(authClient.exchangeCallCount, 1);
        expect(service.status, AuthStatus.unauthenticated);
        expect(service.isRecoverySession, isFalse);
        expect(service.isSignedIn, isFalse);
        expect(service.recoveryCallbackError, isNotNull);
        await service.dispose();
      });

      test('a passwordRecovery event drives AuthStatus.recovery', () async {
        final AuthService service = buildService(authClient: authClient);
        await service.initialize();
        expect(service.status, AuthStatus.unauthenticated);

        authClient.emit(AuthChangeEvent.passwordRecovery, fakeSession('u1'));
        await pumpEventQueue();

        expect(service.status, AuthStatus.recovery);
        expect(service.isRecoverySession, isTrue);
        expect(service.isSignedIn, isFalse);
        await service.dispose();
      });

      test('updatePassword succeeds with a recovery session present', () async {
        final AuthService service = buildService(
          authClient: authClient,
          callbackUri: Uri.parse('http://localhost:8080/reset-password?code=c'),
        );
        await service.initialize();
        expect(service.status, AuthStatus.recovery);

        await service.updatePassword('Newpass1!');

        expect(authClient.updatedPassword, 'Newpass1!');
        await service.dispose();
      });

      test(
        'updatePassword is fail-closed without a recovery session',
        () async {
          final AuthService service = buildService(authClient: authClient);
          await service.initialize();
          expect(service.status, AuthStatus.unauthenticated);

          late final ApiException error;
          try {
            await service.updatePassword('Newpass1!');
            fail('Expected ApiException');
          } on Object catch (e) {
            error = e as ApiException;
          }

          expect(error.code, 'invalid_grant');
          expect(error.kind, ApiExceptionKind.validation);
          await service.dispose();
        },
      );
    });
  });
}
