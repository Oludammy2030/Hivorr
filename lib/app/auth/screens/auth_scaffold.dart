import 'package:flutter/material.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';

/// Shared chrome for the auth screens (login, register, password recovery).
///
/// Centers a constrained pane (VISUAL-IDENTITY.md §9.3) with the stacked brand
/// lockup, a title/subtitle block and the caller's form content. Pure
/// presentation and token-driven (AGENT.md Rule 5).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            child: HivorrContentPane(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: LogoStacked(height: 88)),
                  const SizedBox(height: HivorrSpacing.md),
                  Text(
                    title,
                    style: context.textTheme.headlineMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  Text(
                    subtitle,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HivorrSpacing.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error text used under auth forms; surfaces the safe [message]
/// carried by [ApiException] without leaking raw payloads.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Text(
      message,
      style: context.textTheme.bodySmall?.copyWith(color: colors.error),
      textAlign: TextAlign.center,
    );
  }
}