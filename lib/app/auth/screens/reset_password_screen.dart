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

/// Set-a-new-password flow reachable from the recovery email link.
///
/// Thin UI over [AuthProvider.updatePassword]; the recovery email link
/// carries the session that empowers the password update. Screens both the
/// change-in-progress error and a success confirmation.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _attempted = false;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool valid = _password.text.length >= 6 && _passwordsMatch;
    final String? confirmError = _attempted && !_passwordsMatch
        ? 'Passwords do not match.'
        : null;
    final String? error = _attempted ? auth.lastError?.message : null;

    return AuthScaffold(
      title: 'Set a new password',
      subtitle: 'Choose a strong password for your Hivorr account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_done) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(HivorrSpacing.md),
              decoration: BoxDecoration(
                color: context.appExtension.successContainer,
                borderRadius: BorderRadius.circular(
                  context.appExtension.radiusSm,
                ),
              ),
              child: Text(
                'Your password has been updated. You can now sign in.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.appExtension.onSuccessContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            HivorrButton(
              label: 'Go to sign in',
              isExpanded: true,
              size: HivorrButtonSize.large,
              onPressed: () => context.go(RoutePaths.login),
            ),
          ] else ...<Widget>[
            HivorrTextField(
              controller: _password,
              label: 'New password',
              obscureText: _obscure,
              errorText: _attempted && _password.text.length < 6
                  ? 'Use at least 6 characters.'
                  : null,
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
              label: 'Confirm new password',
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
              label: 'Update password',
              isExpanded: true,
              size: HivorrButtonSize.large,
              isLoading: _submitting,
              onPressed: valid && !_submitting ? _submit : null,
            ),
            const SizedBox(height: HivorrSpacing.md),
            TextButton(
              onPressed: _submitting ? null : () => context.go(RoutePaths.login),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Back to sign in'),
            ),
          ],
        ],
      ),
    );
  }

  bool get _passwordsMatch =>
      _confirm.text.isNotEmpty && _confirm.text == _password.text;

  Future<void> _submit() async {
    setState(() {
      _attempted = true;
      _submitting = true;
    });
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.updatePassword(_password.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _done = true;
    });
  }
}