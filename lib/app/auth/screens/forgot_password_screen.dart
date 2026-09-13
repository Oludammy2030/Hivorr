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

/// Forgot-password request (auth flows §7).
///
/// Sends a recovery email through [AuthProvider.requestPasswordReset]. Always
/// shows a neutral success message (regardless of account existence) so the
/// screen never leaks which addresses are registered.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String? error = _sent ? null : auth.lastError?.message;

    return AuthScaffold(
      title: 'Reset your password',
      subtitle: 'Enter your email and we’ll send recovery instructions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_sent) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(HivorrSpacing.md),
              decoration: BoxDecoration(
                color: context.appExtension.successContainer,
                borderRadius: BorderRadius.circular(
                  context.appExtension.radiusSm,
                ),
              ),
              child: Text(
                'If an account exists for that address, recovery instructions '
                'are on their way.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.appExtension.onSuccessContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...<Widget>[
            HivorrTextField(
              controller: _email,
              label: 'Email address',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              AuthErrorText(message: error),
            ],
            const SizedBox(height: HivorrSpacing.lg),
            HivorrButton(
              label: 'Send recovery email',
              isExpanded: true,
              size: HivorrButtonSize.large,
              isLoading: _submitting,
              onPressed: _email.text.trim().isNotEmpty && !_submitting
                  ? _submit
                  : null,
            ),
          ],
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: _submitting ? null : () => context.go(RoutePaths.login),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.requestPasswordReset(_email.text.trim());
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _sent = true;
    });
  }
}