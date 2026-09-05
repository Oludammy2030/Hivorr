import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/app/app.dart';
import 'package:hivorr/app/app_bootstrap.dart';
import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/startup/error_screen.dart';
import 'package:hivorr/app/startup/initialization_state.dart';
import 'package:hivorr/app/startup/splash_screen.dart';

/// Drives the bootstrap lifecycle and renders the appropriate screen.
///
/// Shows the brand [SplashScreen] while [InitializationState] is `loading`,
/// mounts the app shell on `ready`, and shows the user-safe [FatalErrorScreen]
/// (with retry) on `error`. The [lifecycleObserver] is registered once by the
/// bootstrap entrypoint and disposed here at teardown (EP-01-15 §5.4, §5.6).
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({
    super.key,
    required this.lifecycleObserver,
  });

  final AppLifecycleObserver lifecycleObserver;

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  InitializationState _state = const InitializationLoading();
  BootstrapResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() => _state = const InitializationLoading());
    try {
      final BootstrapResult result = await AppBootstrap.initialize();
      if (!mounted) {
        return;
      }
      _result = result;
      setState(() => _state = const InitializationReady());
    } catch (error) {
      // A structured log via EP-01-14 would be wired here once available.
      // debugPrint is used (not print) to avoid leaking secrets.
      debugPrint('[hivorr.bootstrap] fatal initialization failure');
      if (!mounted) {
        return;
      }
      setState(
        () => _state = const InitializationError(
          'The application could not start. Please check your connection '
          'and try again.',
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.lifecycleObserver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      InitializationError(:final message) => MaterialApp(
          home: FatalErrorScreen(message: message, onRetry: _start),
        ),
      InitializationReady() => HivorrApp(
          authProvider: _result!.authLayer.provider,
          localeProvider: _result!.localeProvider,
          lifecycleObserver: widget.lifecycleObserver,
          taxonomyRepository: _result!.taxonomyRepository,
          taxonomyProvider: _result!.taxonomyProvider,
          verificationRepository: _result!.verificationRepository,
          verificationProvider: _result!.verificationProvider,
          escrowRepository: _result!.escrowRepository,
          escrowProvider: _result!.escrowProvider,
        ),
      _ => const MaterialApp(home: SplashScreen()),
    };
  }
}
