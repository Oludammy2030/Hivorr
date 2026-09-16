import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Manage User detail screen (EP-02-11 admin console).
///
/// Displays a single user's full posture (entity core, profile, roles, KYC,
/// verification summary) plus lifecycle actions: suspend/reactivate/deactivate
/// and admin-initiated onboarding reset. Actions are confirm-gated and
/// fail-closed on server errors (PLT005 lockout guards are server-enforced).
class ManageUserDetailScreen extends StatefulWidget {
  const ManageUserDetailScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<ManageUserDetailScreen> createState() => _ManageUserDetailScreenState();
}

class _ManageUserDetailScreenState extends State<ManageUserDetailScreen> {
  String? _feedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ManageUserProvider>().loadDetail(widget.userId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ManageUserProvider provider = context.watch<ManageUserProvider>();
    final ManageUserDetail? detail = provider.selectedUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('User detail', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: _body(provider, detail),
      ),
    );
  }

  Widget _body(ManageUserProvider provider, ManageUserDetail? detail) {
    if (provider.isLoadingDetail && detail == null) {
      return const HivorrLoadingState();
    }
    if (provider.lastError != null && detail == null) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.search_off,
          color: context.colorScheme.primary,
        ),
        title: 'User not found',
        subtitle: provider.lastError!.message,
      );
    }
    if (detail == null) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.person_off_outlined,
          color: context.colorScheme.primary,
        ),
        title: 'No user selected',
        subtitle: 'Open a user from the directory to view their posture.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      children: <Widget>[
        _entityCard(detail),
        const SizedBox(height: HivorrSpacing.md),
        if (detail.profile != null) ...<Widget>[
          _profileCard(detail.profile!),
          const SizedBox(height: HivorrSpacing.md),
        ],
        _rolesCard(detail),
        const SizedBox(height: HivorrSpacing.md),
        _kycCard(detail),
        const SizedBox(height: HivorrSpacing.md),
        _summaryCard(detail),
        const SizedBox(height: HivorrSpacing.md),
        _actionsCard(provider, detail),
        const SizedBox(height: HivorrSpacing.md),
        if (_feedback != null && _feedback!.isNotEmpty)
          Text(
            _feedback!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _entityCard(ManageUserDetail detail) {
    final ManageUserEntityCore entity = detail.entity;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _entityName(detail),
                  style: context.textTheme.titleMedium,
                ),
              ),
              _statusChip(entity.status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          _infoRow('Entity ID', entity.id),
          _infoRow('Capability', entity.capability ?? '—'),
          _infoRow(
            'Onboarding',
            entity.onboardingCompletedAt == null
                ? 'Not completed'
                : 'Completed ${_formatDate(entity.onboardingCompletedAt!)}',
          ),
          _infoRow('Joined', _formatDate(entity.createdAt)),
          if (detail.isAdmin)
            Text(
              'Platform admin',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileCard(ManageUserProfile profile) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Profile', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          _infoRow('Display name', profile.displayName ?? '—'),
          _infoRow('Legal name', profile.legalName ?? '—'),
          _infoRow('Country', profile.countryCode ?? '—'),
          if (profile.bio != null && profile.bio!.isNotEmpty)
            _infoRow('Bio', profile.bio!),
        ],
      ),
    );
  }

  Widget _rolesCard(ManageUserDetail detail) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Roles', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          if (detail.roles.isEmpty)
            Text(
              'No roles assigned.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final ManageUserRoleAssignment role in detail.roles)
              Padding(
                padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
                child: Text(
                  '${role.role} — ${role.isActive ? 'active' : 'inactive'}',
                  style: context.textTheme.bodyMedium,
                ),
              ),
        ],
      ),
    );
  }

  Widget _kycCard(ManageUserDetail detail) {
    final ManageUserKycSummary? kyc = detail.kyc;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('KYC', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          if (kyc == null)
            Text(
              'No KYC level assigned.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          else ...<Widget>[
            _infoRow('Tier', kyc.tierCode ?? '—'),
            _infoRow('Status', kyc.status ?? '—'),
            if (kyc.assignedAt != null)
              _infoRow('Assigned', _formatDate(kyc.assignedAt!)),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(ManageUserDetail detail) {
    final ManageUserVerificationSummary summary = detail.summary;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Verification summary', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          _infoRow('Credentials', '${summary.credentialCount}'),
          _infoRow('Approved credentials', '${summary.approvedCredentials}'),
          _infoRow('Pending submissions', '${summary.pendingSubmissions}'),
          _infoRow('Total submissions', '${summary.totalSubmissions}'),
        ],
      ),
    );
  }

  Widget _actionsCard(ManageUserProvider provider, ManageUserDetail detail) {
    final String status = detail.entity.status;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Lifecycle', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          if (status == 'active') ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: HivorrButton(
                    label: 'Suspend',
                    variant: HivorrButtonVariant.outline,
                    isLoading: provider.isActing,
                    onPressed: () => _setStatus(provider, detail, 'suspended'),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: HivorrButton(
                    label: 'Deactivate',
                    variant: HivorrButtonVariant.outline,
                    isLoading: provider.isActing,
                    onPressed: () => _setStatus(provider, detail, 'deactivated'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HivorrSpacing.sm),
          ] else if (status == 'suspended' || status == 'deactivated') ...<Widget>[
            HivorrButton(
              label: 'Reactivate',
              isExpanded: true,
              isLoading: provider.isActing,
              onPressed: () => _setStatus(provider, detail, 'active'),
            ),
            const SizedBox(height: HivorrSpacing.sm),
          ],
          HivorrButton(
            label: 'Reset onboarding',
            variant: HivorrButtonVariant.text,
            isLoading: provider.isActing,
            onPressed: () => _resetOnboarding(provider, detail),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(
    ManageUserProvider provider,
    ManageUserDetail detail,
    String status,
  ) async {
    final bool confirmed = await _confirm(
      context,
      title: _statusActionLabel(status),
      message: _statusActionMessage(status, _entityName(detail)),
      confirmLabel: _statusActionLabel(status),
    );
    if (!confirmed || !mounted) return;
    await provider.setUserStatus(detail.entity.id, status);
    if (!mounted) return;
    setState(() {
      _feedback = provider.lastError == null
          ? 'Status updated to $status.'
          : 'Action failed: ${provider.lastError!.message}';
    });
  }

  Future<void> _resetOnboarding(
    ManageUserProvider provider,
    ManageUserDetail detail,
  ) async {
    final bool confirmed = await _confirm(
      context,
      title: 'Reset onboarding',
      message:
          'Clear capability and the completion stamp for ${_entityName(detail)}? '
          'The user will need to complete onboarding again.',
      confirmLabel: 'Reset',
    );
    if (!confirmed || !mounted) return;
    await provider.resetOnboarding(detail.entity.id);
    if (!mounted) return;
    setState(() {
      _feedback = provider.lastError == null
          ? 'Onboarding reset — user must re-onboard.'
          : 'Reset failed: ${provider.lastError!.message}';
    });
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _statusChip(String status) {
    final Color color = switch (status) {
      'active' => context.colorScheme.primary,
      'suspended' => context.colorScheme.error,
      'deactivated' => context.colorScheme.onSurfaceVariant,
      _ => context.colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: HivorrSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: context.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _entityName(ManageUserDetail detail) {
    final String? display = detail.profile?.displayName;
    final String name = (display ?? '').isNotEmpty
        ? display!
        : (detail.profile?.legalName ?? '');
    return name.isNotEmpty ? name : detail.entity.id;
  }

  String _statusActionLabel(String status) => switch (status) {
        'active' => 'Reactivate',
        'suspended' => 'Suspend',
        'deactivated' => 'Deactivate',
        _ => 'Update status',
      };

  String _statusActionMessage(String status, String name) => switch (status) {
        'active' => 'Reactivate $name? This restores full account access.',
        'suspended' => 'Suspend $name? The account is temporarily disabled.',
        'deactivated' => 'Deactivate $name? The account is permanently disabled.',
        _ => 'Update the status for $name?',
      };

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}