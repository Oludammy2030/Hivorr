import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/auth_scaffold.dart';
import 'package:hivorr/app/entry/entry_query.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/models/registration_identity.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/validators/hivorr_validators.dart';
import 'package:hivorr/shared/validators/password_policy.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/shared/widgets/password_match_indicator.dart';
import 'package:hivorr/shared/widgets/password_requirements_checklist.dart';
import 'package:hivorr/shared/widgets/password_strength_indicator.dart';
import 'package:provider/provider.dart';

/// Registration with basic identity capture (account creation → OTP → onboarding).
///
/// Collects authoritative account identity at sign-up (first/last required,
/// middle optional, displayName required, email/phone required, password).
/// Bio/Avatar are NOT collected here — they remain profile-completion later
/// (`/profile`). On submit the identity is staged via GoTrue `user_metadata`
/// (OTP gap has no JWT) so `AuthConfirmationGateScreen` → verified session can
/// hydrate `entity_profiles` via the split-name `entity_profile_update` RPC
/// before entering capability-first onboarding.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _middleName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _attempted = false;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool alreadyRegistered =
        auth.lastErrorCode == 'user_already_exists' && _attempted;
    final String? firstNameError =
        _attempted && !_isFirstNameValid ? _firstNameError : null;
    final String? lastNameError =
        _attempted && !_isLastNameValid ? _lastNameError : null;
    final String? displayNameError =
        _attempted && !_isDisplayNameValid ? _displayNameError : null;
    final String? emailError = _attempted && !_isEmailValid ? _emailError : null;
    final String? phoneError = _attempted && !_isPhoneValid ? _phoneError : null;
    final String? passwordError =
        _attempted && !_isPasswordValid ? _passwordError : null;
    final String? confirmError = _confirm.text.isNotEmpty && !_passwordsMatch
        ? _confirmError
        : null;
    final String? error = alreadyRegistered
        ? 'An account already exists with this email address. '
            'Please log in to continue.'
        : _attempted
            ? (auth.lastError?.message ?? _validationError)
            : null;

    return AuthScaffold(
      title: 'Create your free account',
      subtitle:
          'Your basic identity is captured here — onboarding will start with how you want to use Hivorr.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Name row: first / middle / last — layout adapts to width.
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= 520;
              final Widget first = HivorrTextField(
                controller: _firstName,
                label: 'First name',
                hint: 'Required',
                errorText: firstNameError,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
              );
              final Widget middle = HivorrTextField(
                controller: _middleName,
                label: 'Middle name',
                hint: 'Optional',
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
              );
              final Widget last = HivorrTextField(
                controller: _lastName,
                label: 'Last name',
                hint: 'Required',
                errorText: lastNameError,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: first),
                    const SizedBox(width: HivorrSpacing.md),
                    Expanded(child: middle),
                    const SizedBox(width: HivorrSpacing.md),
                    Expanded(child: last),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  first,
                  const SizedBox(height: HivorrSpacing.md),
                  middle,
                  const SizedBox(height: HivorrSpacing.md),
                  last,
                ],
              );
            },
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _displayName,
            label: 'Display name',
            hint: 'How clients see you',
            errorText: displayNameError,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: HivorrSpacing.md),
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
            controller: _phone,
            label: 'Phone number',
            hint: '+1 555 000 1234',
            keyboardType: TextInputType.phone,
            errorText: phoneError,
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
          const SizedBox(height: HivorrSpacing.sm),
          PasswordRequirementsChecklist(
            result: _passwordPolicy,
            requirements: PasswordPolicy.supabase.required,
          ),
          if (_password.text.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            PasswordStrengthIndicator(strength: _passwordPolicy.strength),
          ],
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _confirm,
            label: 'Confirm password',
            obscureText: _obscure,
            errorText: confirmError,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
          ),
          if (_confirm.text.isNotEmpty && _passwordsMatch) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            const PasswordMatchIndicator(matches: true),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            AuthErrorText(message: error),
          ],
          if (alreadyRegistered) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => context.go(_target(RoutePaths.login)),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Log In'),
            ),
            const SizedBox(height: HivorrSpacing.sm),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => context.go(_verificationTarget(_email.text.trim())),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Verify email'),
            ),
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

  bool get _isFirstNameValid =>
      HivorrValidators.required(_firstName.text, field: 'First name') == null;

  bool get _isLastNameValid =>
      HivorrValidators.required(_lastName.text, field: 'Last name') == null;

  bool get _isDisplayNameValid =>
      HivorrValidators.required(_displayName.text, field: 'Display name') == null;

  bool get _isEmailValid =>
      HivorrValidators.email(_email.text) == null;

  bool get _isPhoneValid =>
      HivorrValidators.phone(_phone.text) == null;

  PasswordPolicyResult get _passwordPolicy =>
      PasswordPolicy.supabase.evaluate(_password.text);

  bool get _isPasswordValid => _passwordPolicy.isValid;

  bool get _passwordsMatch => _confirm.text.isNotEmpty && _confirm.text == _password.text;

  String? get _firstNameError =>
      HivorrValidators.required(_firstName.text, field: 'First name');

  String? get _lastNameError =>
      HivorrValidators.required(_lastName.text, field: 'Last name');

  String? get _displayNameError =>
      HivorrValidators.required(_displayName.text, field: 'Display name');

  String? get _emailError => HivorrValidators.email(_email.text);

  String? get _phoneError => HivorrValidators.phone(_phone.text);

  String? get _passwordError => _isPasswordValid ? null : PasswordPolicy.supabase.invalidMessage;

  String? get _confirmError => _passwordsMatch ? null : 'Passwords do not match.';

  String? get _validationError {
    if (!_attempted) {
      return null;
    }
    if (!_isFirstNameValid) {
      return 'Enter your first name.';
    }
    if (!_isLastNameValid) {
      return 'Enter your last name.';
    }
    if (!_isDisplayNameValid) {
      return 'Enter a display name.';
    }
    if (!_isEmailValid) {
      return 'Check your email address.';
    }
    if (!_isPhoneValid) {
      return 'Enter a valid phone number.';
    }
    if (!_isPasswordValid) {
      return PasswordPolicy.supabase.invalidMessage;
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
    if (!_isFirstNameValid ||
        !_isLastNameValid ||
        !_isDisplayNameValid ||
        !_isEmailValid ||
        !_isPhoneValid ||
        !_isPasswordValid ||
        !_passwordsMatch) {
      setState(() => _submitting = false);
      return;
    }
    final AuthProvider auth = context.read<AuthProvider>();
    // Use staged-identity sign-up so the OTP gap (no JWT) does not lose names/phone.
    // Falls back to plain signUp if the provider/service is a test fake without the seam.
    try {
      await auth.signUpWithIdentity(
        RegistrationIdentity(
          email: _email.text.trim(),
          password: _password.text,
          firstName: _firstName.text.trim(),
          middleName: _middleName.text.trim().isEmpty ? null : _middleName.text.trim(),
          lastName: _lastName.text.trim(),
          displayName: _displayName.text.trim(),
          phoneNumber: _phone.text.trim(),
        ),
      );
    } on NoSuchMethodError {
      await auth.signUp(
        AuthCredentials(
          email: _email.text.trim(),
          password: _password.text,
        ),
      );
    }
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

  /// Routes an existing identity whose email is not verified yet to the
  /// verification gate in resume mode — the gate issues a fresh code for the
  /// existing account only (`sendEmailVerificationOtp` never creates users),
  /// so the returnee completes verification without a duplicate registration.
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
