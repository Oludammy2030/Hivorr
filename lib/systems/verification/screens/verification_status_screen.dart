import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/verification/widgets/identity_verified_badge.dart';
import 'package:hivorr/systems/verification/widgets/kyc_level_card.dart';
import 'package:hivorr/systems/verification/widgets/verification_timeline.dart';
import 'package:provider/provider.dart';

/// Screen summarising the identity-verification status (EP-02-10 §5.6, §10).
///
/// Consumes [VerificationProvider], kicks off a status refresh on init and
/// polls every 15s until identity is verified (see provider). Renders the
/// [IdentityVerifiedBadge], [KycLevelCard] and a [VerificationTimeline] derived
/// from the server aggregate. All theming via [AppTheme] tokens.
class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen>
    with WidgetsBindingObserver {
  late final VerificationProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<VerificationProvider>();
    _provider.startPolling();
    // Defer the initial refresh out of the build phase: refreshStatus()
    // synchronously notifies listeners, which is illegal mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_provider.refreshStatus());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.stopPolling();
    super.dispose();
  }

  /// TV-10: pauses the 15s poller while the app is backgrounded and resumes it
  /// on foreground (no wasted RPCs on a backgrounded screen).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.resumePolling();
    } else {
      _provider.pausePolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final VerificationProvider provider = context.watch<VerificationProvider>();
    final VerificationStatus? status = provider.status;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verification', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(child: _body(context, provider, status)),
    );
  }

  Widget _body(
    BuildContext context,
    VerificationProvider provider,
    VerificationStatus? status,
  ) {
    if (status == null) {
      if (provider.isRefreshing || provider.submitState.name == 'submitting') {
        return const HivorrLoadingState(
          message: 'Checking your verification status…',
        );
      }
      if (provider.lastError != null) {
        return HivorrErrorState(
          message: provider.lastError?.message ?? 'Unable to load status.',
          onRetry: provider.refreshStatus,
        );
      }
      return const HivorrLoadingState(message: 'Checking your status…');
    }

    final VerificationStatusKind timelineStatus = switch (provider.stage) {
      VerificationStage.approved => VerificationStatusKind.approved,
      VerificationStage.actionRequired => VerificationStatusKind.requiresResubmission,
      _ => status.totalSubmissions > 0
          ? VerificationStatusKind.inReview
          : VerificationStatusKind.pending,
    };

    final bool actionRequired =
        provider.stage == VerificationStage.actionRequired;

    return RefreshIndicator(
      onRefresh: provider.refreshStatus,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        children: <Widget>[
          if (actionRequired) ...<Widget>[
            HivorrErrorState(
              message: "Your document couldn't be verified.",
              detail: 'Please review the feedback and resubmit a clear '
                  'document to continue, or contact support.',
              actionLabel: 'Resubmit',
              onAction: () => context.push(RoutePaths.verificationIdentity),
              onRetry: provider.refreshStatus,
            ),
            const SizedBox(height: HivorrSpacing.lg),
          ] else if (status.identityVerified) ...<Widget>[
            IdentityVerifiedBadge(
              label: 'Identity Verified',
              subtitle: status.kycLevel.tierCode,
            ),
            const SizedBox(height: HivorrSpacing.lg),
          ] else ...<Widget>[
            _Header(colors: context.colorScheme),
            const SizedBox(height: HivorrSpacing.md),
            HivorrButton(
              label: 'Upload a document',
              isExpanded: true,
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: () => context.push(RoutePaths.verificationIdentity),
            ),
            const SizedBox(height: HivorrSpacing.lg),
          ],
          VerificationTimeline(
            status: timelineStatus,
            decisionNotes: _decisionNotes(provider),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          if (provider.kycLevel != null ||
              status.kycLevel.tierCode != 'tier_0') ...<Widget>[
            KycLevelCard(level: provider.kycLevel ?? status.kycLevel),
            const SizedBox(height: HivorrSpacing.lg),
          ],
          _CounterRow(
            icon: Icons.hourglass_top,
            label: 'Pending submissions',
            value: status.pendingSubmissions,
            colors: context.colorScheme,
          ),
          const SizedBox(height: HivorrSpacing.xs),
          _CounterRow(
            icon: Icons.inbox_outlined,
            label: 'Total submissions',
            value: status.totalSubmissions,
            colors: context.colorScheme,
          ),
        ],
      ),
    );
  }

  /// Admin feedback for a decided submission, when the aggregate carries it.
  String? _decisionNotes(VerificationProvider provider) {
    final String? notes = provider.lastSubmission?.decisionNotes;
    if (notes == null || notes.isEmpty) return null;
    return notes;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Complete your identity verification to unlock higher tier_1 limits.',
      style: context.textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final int value;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: colors.onSurfaceVariant),
        const SizedBox(width: HivorrSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        Text('$value', style: context.textTheme.titleMedium),
      ],
    );
  }
}
