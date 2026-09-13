import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/auth_scaffold.dart';
import 'package:hivorr/app/entry/entry_query.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:provider/provider.dart';

/// Registration (register → account creation → onboarding handoff).
///
/// Captures credentials only: account provisioning is the existing
/// RLS-scoped [AuthService.ensureEntityExists] and Basic Information stays in
/// onboarding (correction plan §6, §8). On success the entity is routed
/// onward; when the environment requires email confirmation, the register
/// flow hands off to the [AuthConfirmationGateScreen].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _attempted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String? emailError = _attempted && !_isEmailValid ? _emailError : null;
    final String? passwordError =
        _attempted && !_isPasswordValid ? _passwordError : null;
    final String? confirmError =
        _attempted && !_passwordsMatch ? _confirmError : null;
    final String? serverError = _attempted ? auth.lastError?.message : null;
    final String? error =
        (serverError ?? _validationError);

    return AuthScaffold(
      title: 'Create your free account',
      subtitle:
          'One verified identity for professional, client and every other '
          'role. Basic Information comes right after.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivorrTextField(
            controller: _email,
            label: 'Email address',
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            errorText: emailError,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _password,
            label: 'Password',
            obscureText: _obscure,
            errorText: passwordError,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _confirm,
            label: 'Confirm password',
            obscureText: _obscure,
            errorText: confirmError,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            AuthErrorText(message: error),
          ],
          const SizedBox(height: HivorrSpacing.lg),
          HivorrButton(
            label: 'Create account',
            isExpanded: true,
            size: HivorrButtonSize.large,
            isLoading: _submitting,
            onPressed: _canSubmit ? _submit : null,
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: _submitting ? null : () => context.go(_target(RoutePaths.login)),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }

  bool get _isEmailValid =>
      _email.text.trim().isNotEmpty && _email.text.contains('@');

  bool get _isPasswordValid => _password.text.length >= 6;

  bool get _passwordsMatch => _confirm.text.isNotEmpty && _confirm.text == _password.text;

  String? get _emailError => _isEmailValid ? null : 'Enter a valid email address.';

  String? get _passwordError =>
      _isPasswordValid ? null : 'Use at least 6 characters.';

  String? get _confirmError => _passwordsMatch ? null : 'Passwords do not match.';

  String? get _validationError {
    if (!_attempted) {
      return null;
    }
    if (!_isEmailValid) {
      return 'Check your email address.';
    }
    if (!_isPasswordValid) {
      return 'Password must be at least 6 characters.';
    }
    if (!_passwordsMatch) {
      return 'Passwords do not match.';
    }
    return null;
  }

  bool get _canSubmit => !_submitting;

  Future<void> _submit() async {
    setState(() {
      _attempted = true;
      _submitting = true;
    });
    if (!_isEmailValid || !_isPasswordValid || !_passwordsMatch) {
      setState(() => _submitting = false);
      return;
    }
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.signUp(
      AuthCredentials(email: _email.text.trim(), password: _password.text),
    );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (auth.isSignedIn) {
      context.go(_afterSignIn());
      return;
    }
    if (auth.status == AuthStatus.awaitingEmailConfirmation) {
      context.go(_confirmationTarget());
    }
  }

  String _afterSignIn() {
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    if (next != null && next.isNotEmpty) {
      return next;
    }
    return RoutePaths.home;
  }

  /// Routes to the confirmation gate, carrying the email + preserved target.
  String _confirmationTarget() {
    final String email =
        Uri.encodeQueryComponent(_email.text.trim());
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    final String nextParam = (next == null || next.isEmpty)
        ? ''
        : '&next=${Uri.encodeQueryComponent(next)}';
    return '${RoutePaths.authConfirmation}?email=$email$nextParam';
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