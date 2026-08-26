import 'package:flutter/material.dart';

import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';

/// Brand splash shown immediately at launch while the app initializes.
///
/// Stateless and dependency-free so it can render before any core system is
/// wired (EP-01-15 §5.6). Must not contain business logic.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LogoHorizontal(),
            const SizedBox(height: 24),
            HivorrLoader(color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
