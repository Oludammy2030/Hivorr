import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/auth_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:provider/provider.dart';

/// Email-confirmation gate (register → account-creation handoff, §6).
///
/// Shown after a sign-up when the environment requires email confirmation.
/// Watches [AuthProvider] and auto-continues to the preserved destination once
/// the confirmation session arrives (auth-state stream flips status); the
/// visitor can also return to sign-in at any time.
class AuthConfirmationGateScreen extends StatefulWidget {
  const AuthConfirmationGateScreen({super.key, this.email, this.next});

  /// The email the confirmation was sent to, when provided on the route.
  final String? email;

  /// The preserved post-confirmation destination (`?next=`).
  final String? next;

  @override
  State<AuthConfirmationGateScreen> createState() =>
      _AuthConfirmationGateScreenState();
}

class _AuthConfirmationGateScreenState
    extends State<AuthConfirmationGateScreen> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    if (auth.isSignedIn) {
      _advance();
    }

    final String email = widget.email ?? auth.currentSession?.email ?? '';

    return AuthScaffold(
      title: 'Confirm your email',
      subtitle: email.isEmpty
          ? 'We sent a confirmation link to your inbox.'
          : 'We sent a confirmation link to\n$email.',
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
              'Open the link to activate your account. Once confirmed, '
              'we’ll continue automatically to your account and onboarding.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          HivorrButton(
            label: auth.isSignedIn ? 'Continue' : 'Waiting for confirmation…',
            isExpanded: true,
            size: HivorrButtonSize.large,
            onPressed: auth.isSignedIn ? _advance : null,
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: () => context.go(_target(RoutePaths.login)),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.primary,
            ),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
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