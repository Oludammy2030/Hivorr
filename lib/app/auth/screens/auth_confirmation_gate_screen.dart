import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/auth_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:provider/provider.dart';

/// Email-verification gate (register → account-creation handoff, §6).
///
/// Shown after a sign-up in environments that require email confirmation, and
/// in resume mode when an existing identity's email is not verified yet. The
/// visitor enters the 6-digit code that was emailed (email-OTP); verifying
/// activates the session and [AuthProvider] auto-continues to the preserved
/// destination once the auth-state stream flips. The code can be resent —
/// subject to a client-side cooldown that mirrors gotrue's send rate limits —
/// or the visitor can return to sign-in at any time.
class AuthConfirmationGateScreen extends StatefulWidget {
  const AuthConfirmationGateScreen({
    super.key,
    this.email,
    this.next,
    this.mode,
  });

  /// The email the confirmation was sent to, when provided on the route.
  final String? email;

  /// The preserved post-confirmation destination (`?next=`).
  final String? next;

  /// `resume` signals an existing identity resuming verification (login /
  /// guard redirect); the gate then issues a fresh code on entry.
  final String? mode;

  @override
  State<AuthConfirmationGateScreen> createState() =>
      _AuthConfirmationGateScreenState();
}

class _AuthConfirmationGateScreenState
    extends State<AuthConfirmationGateScreen> {
  final TextEditingController _code = TextEditingController();
  bool _submitting = false;
  bool _attempted = false;
  bool _navigated = false;
  bool _initialSendDone = false;
  Timer? _cooldownTimer;
  Duration _cooldownRemaining = Duration.zero;

  /// How long the resend action is unavailable after a send (mirrors the
  /// gotrue email-send cooldown without depending on server responses).
  static const Duration _resendCooldown = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    if (widget.mode == RoutePaths.authVerificationResumeMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final String email = widget.email ?? '';
        if (mounted && !_initialSendDone && email.isNotEmpty) {
          unawaited(_sendCode(email));
        }
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    if (auth.isSignedIn) {
      _advance();
    }

    final String email = widget.email ?? auth.currentSession?.email ?? '';
    final String? error = _attempted && !_submitting
        ? auth.lastError?.message
        : null;
    final bool resendCooldown = _cooldownRemaining > Duration.zero;
    final bool canResend = !_submitting && email.isNotEmpty && !resendCooldown;

    return AuthScaffold(
      title: 'Confirm your email',
      subtitle: email.isEmpty
          ? 'Enter the 6-digit code sent to your email address.'
          : 'Enter the 6-digit code sent to\n$email.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(
                context.appExtension.radiusSm,
              ),
            ),
            child: Text(
              auth.isSignedIn
                  ? 'Your account is ready — continuing to your account and '
                      'onboarding.'
                  : 'Enter the code to verify your email. Once verified, '
                      'we’ll continue automatically to your account and '
                      'onboarding.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          HivorrTextField(
            controller: _code,
            label: 'Verification code',
            hint: '6-digit code',
            enabled: !_submitting,
            maxLength: 6,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            AuthErrorText(message: error),
          ],
          const SizedBox(height: HivorrSpacing.lg),
          HivorrButton(
            label: 'Verify code',
            isExpanded: true,
            size: HivorrButtonSize.large,
            isLoading: _submitting,
            onPressed: (_submitting ||
                    _code.text.trim().isEmpty ||
                    auth.isSignedIn)
                ? null
                : _verify,
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: canResend ? () => _sendCode(email) : null,
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.primary,
            ),
            child: Text(_resendLabel(resendCooldown)),
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: _submitting
                ? null
                : () => context.go(_target(RoutePaths.login)),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.primary,
            ),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  /// The resend label, showing a countdown while the cooldown is active.
  String _resendLabel(bool resendCooldown) {
    if (!resendCooldown) {
      return 'Resend code';
    }
    final int seconds = _cooldownRemaining.inSeconds;
    final String minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final String remainder = (seconds % 60).toString().padLeft(2, '0');
    return 'Resend code in $minutes:$remainder';
  }

  Future<void> _sendCode(String email) async {
    final AuthProvider auth = context.read<AuthProvider>();
    setState(() {
      _attempted = true;
      _initialSendDone = true;
      _cooldownRemaining = _resendCooldown;
    });
    _startCooldownTimer();
    await auth.sendEmailVerificationOtp(email);
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining -= const Duration(seconds: 1);
      });
      if (_cooldownRemaining <= Duration.zero) {
        timer.cancel();
        _cooldownRemaining = Duration.zero;
      }
    });
  }

  Future<void> _verify() async {
    setState(() {
      _attempted = true;
      _submitting = true;
    });
    final AuthProvider auth = context.read<AuthProvider>();
    final String email = widget.email ?? auth.currentSession?.email ?? '';
    await auth.verifyEmailOtp(email: email, code: _code.text.trim());
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
  }

  /// Navigates to the preserved destination (or home) exactly once.
  void _advance() {
    if (_navigated) {
      return;
    }
    _navigated = true;
    final String? next = widget.next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go(next == null || next.isEmpty ? RoutePaths.home : next);
    });
  }

  /// Carries the preserved `?next=` when returning to sign-in.
  String _target(String route) {
    final String? next = widget.next;
    if (next == null || next.isEmpty) {
      return route;
    }
    return '$route?next=$next';
  }
}