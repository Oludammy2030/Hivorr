import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/auth_scaffold.dart';
import 'package:hivorr/app/entry/entry_query.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:provider/provider.dart';

/// Email + password sign-in (auth flows §7 of the correction plan).
///
/// Thin UI over [AuthProvider.signIn]: validates locally, calls the service
/// once, and routes to the preserved `?next=` destination (or home — the
/// RouteGuard then applies the onboarding resume gate) on success. When the
/// identity exists but its email is not verified yet (gotrue
/// `email_not_confirmed`, e.g. an abandoned registration), the visitor is sent
/// to the verification gate in resume mode, which issues a fresh code and then
/// continues to onboarding — never creating a duplicate account. Errors are
/// surfaced as the safe [ApiException.message]. No business logic here.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String? error = auth.lastError?.message;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue operating your Hivorr account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivorrTextField(
            controller: _email,
            label: 'Email address',
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _password,
            label: 'Password',
            obscureText: _obscure,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            AuthErrorText(message: error),
          ],
          const SizedBox(height: HivorrSpacing.lg),
          HivorrButton(
            label: 'Sign in',
            isExpanded: true,
            size: HivorrButtonSize.large,
            isLoading: _submitting,
            onPressed: _canSubmit ? _submit : null,
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: _submitting
                ? null
                : () => context.go(RoutePaths.forgotPassword),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Forgot password?'),
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: _submitting
                ? null
                : () => context.go(
                    _target(RoutePaths.signup),
                  ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('New here? Create your free account'),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty && !_submitting;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final AuthProvider auth = context.read<AuthProvider>();
    final String email = _email.text.trim();
    await auth.signIn(
      AuthCredentials(email: email, password: _password.text),
    );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (auth.isSignedIn) {
      context.go(_target(_afterSignIn()));
      return;
    }
    if (auth.lastErrorCode == 'email_not_confirmed' ||
        auth.lastErrorCode == 'email_not_verified') {
      context.go(_verificationTarget(email));
    }
  }

  String _afterSignIn() {
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    if (next != null && next.isNotEmpty) {
      return next;
    }
    return RoutePaths.home;
  }

  /// Routes an unverified identity to the verification gate in resume mode.
  ///
  /// The gate will issue a fresh code on entry; verifying it confirms the email
  /// and continues to onboarding. No session exists yet, so nothing is lost by
  /// leaving login.
  String _verificationTarget(String email) {
    final String encodedEmail = Uri.encodeQueryComponent(email);
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    final String nextParam = (next == null || next.isEmpty)
        ? ''
        : '&next=${Uri.encodeQueryComponent(next)}';
    return '${RoutePaths.authConfirmation}?email=$encodedEmail'
        '&mode=${RoutePaths.authVerificationResumeMode}$nextParam';
  }

  /// Carries the preserved `?next=` across auth routes.
  String _target(String route) {
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    if (next == null || next.isEmpty) {
      return route;
    }
    return '$route?next=$next';
  }
}