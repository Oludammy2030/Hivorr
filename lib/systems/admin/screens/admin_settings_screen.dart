import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/localization/locale_provider.dart';
import 'package:hivorr/data/providers/admin_config_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/validators/password_policy.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/password_requirements_checklist.dart';
import 'package:provider/provider.dart';

/// Admin Settings: staged platform configuration (Admin Dashboard).
///
/// Visual source of truth: Admin Dashboard Settings reference screenshot —
/// `Platform Settings` title, a `Fee Configuration` card (2-column filled
/// inputs + blue `Save Configuration`), and a `Platform Toggles` card
/// (label + switch rows). Below the reference cards, two compact cards
/// preserve existing real settings that the screenshot does not show:
/// Language ([LocaleProvider]) and Security (password change via
/// [AuthProvider.updatePassword]).
///
/// Functional source of truth: existing Hivorr architecture. A codebase +
/// migration audit found no platform-config backend RPC (`platform_config`
/// only carries ranking weights, service-role writable), so fee/toggle
/// values are staged through [AdminConfigProvider] on this device (Hive via
/// the shared [StorageEngine], mirroring [LocaleProvider]) with validation,
/// loading/saving/success/error states — and labelled as staged, never
/// implying platform enforcement. No duplicate services or routes.
/// Fail-closed via [AdminGate] like every admin screen.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final TextEditingController _fee = TextEditingController();
  final TextEditingController _escrowDays = TextEditingController();
  final TextEditingController _maxBudget = TextEditingController();
  final TextEditingController _minBudget = TextEditingController();
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    if (!mounted) return;
    final AdminReviewProvider admin = context.read<AdminReviewProvider>();
    await admin.checkAdmin();
    if (!mounted) return;
    if (!AdminGate.isAdmin(admin)) return;
    try {
      final AdminConfigProvider config = context.read<AdminConfigProvider>();
      if (!config.isHydrated) {
        await config.load();
      }
    } catch (_) {
      // Provider absent in isolated tests — screen shows unavailable state.
    }
  }

  @override
  void dispose() {
    _fee.dispose();
    _escrowDays.dispose();
    _maxBudget.dispose();
    _minBudget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminReviewProvider admin = context.watch<AdminReviewProvider>();

    if (!AdminGate.isAdmin(admin)) {
      return SafeArea(
        child: HivorrEmptyState(
          icon: Icon(Icons.admin_panel_settings_outlined,
              color: context.colorScheme.primary),
          title: 'Admin access required',
          subtitle: 'You do not have platform admin privileges.',
        ),
      );
    }

    final AdminConfigProvider? config = _maybeConfig(context);
    if (config == null) {
      return SafeArea(
        child: HivorrEmptyState(
          icon: Icon(Icons.settings_outlined,
              color: context.colorScheme.primary),
          title: 'Settings unavailable',
          subtitle: 'Configuration storage is not connected here.',
        ),
      );
    }
    if (!config.isHydrated) {
      return const SafeArea(child: HivorrLoadingState());
    }
    if (!_synced) {
      _fee.text = _trimNum(config.platformFeePercent);
      _escrowDays.text = '${config.escrowReleaseDays}';
      _maxBudget.text = _trimNum(config.maxJobBudgetUsd);
      _minBudget.text = _trimNum(config.minJobBudgetUsd);
      _synced = true;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoCol = constraints.maxWidth >= 700;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Platform Settings',
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: HivorrSpacing.lg),
                  _FeeCard(
                    twoCol: twoCol,
                    fee: _fee,
                    escrowDays: _escrowDays,
                    maxBudget: _maxBudget,
                    minBudget: _minBudget,
                  ),
                  const SizedBox(height: HivorrSpacing.lg),
                  const _TogglesCard(),
                  const SizedBox(height: HivorrSpacing.lg),
                  const _PreferencesCard(),
                  const SizedBox(height: HivorrSpacing.lg),
                  const _SecurityCard(),
                  const SizedBox(height: HivorrSpacing.lg),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  AdminConfigProvider? _maybeConfig(BuildContext context) {
    try {
      return context.watch<AdminConfigProvider>();
    } catch (_) {
      return null;
    }
  }

  String _trimNum(double value) {
    final String text = value.toString();
    if (text.endsWith('.0')) {
      return text.substring(0, text.length - 2);
    }
    return text;
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small honesty caption: staged-on-device values are not platform enforced.
class _StagedNote extends StatelessWidget {
  const _StagedNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Staged on this device — platform enforcement needs a config backend.',
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Fee Configuration card from the reference: 2-column filled inputs +
/// blue Save button, wired to [AdminConfigProvider] with validation.
class _FeeCard extends StatefulWidget {
  const _FeeCard({
    required this.twoCol,
    required this.fee,
    required this.escrowDays,
    required this.maxBudget,
    required this.minBudget,
  });

  final bool twoCol;
  final TextEditingController fee;
  final TextEditingController escrowDays;
  final TextEditingController maxBudget;
  final TextEditingController minBudget;

  @override
  State<_FeeCard> createState() => _FeeCardState();
}

class _FeeCardState extends State<_FeeCard> {
  String? _feeError;
  String? _daysError;
  String? _maxError;
  String? _minError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AdminConfigProvider config = context.watch<AdminConfigProvider>();

    Widget field({
      required String label,
      required TextEditingController controller,
      required String? error,
      required bool integer,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          TextField(
            controller: controller,
            keyboardType: integer
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              filled: true,
              fillColor:
                  colors.surfaceContainerHighest.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.error),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              errorText: error,
            ),
          ),
        ],
      );
    }

    final List<Widget> fields = <Widget>[
      field(
        label: 'Platform Fee (%)',
        controller: widget.fee,
        error: _feeError,
        integer: false,
      ),
      field(
        label: 'Escrow Release Period (days)',
        controller: widget.escrowDays,
        error: _daysError,
        integer: true,
      ),
      field(
        label: 'Max Job Budget (USD)',
        controller: widget.maxBudget,
        error: _maxError,
        integer: false,
      ),
      field(
        label: 'Min Job Budget (USD)',
        controller: widget.minBudget,
        error: _minError,
        integer: false,
      ),
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Fee Configuration',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          if (widget.twoCol)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: fields[0]),
                const SizedBox(width: HivorrSpacing.md),
                Expanded(child: fields[1]),
              ],
            )
          else
            fields[0],
          SizedBox(
              height: widget.twoCol ? HivorrSpacing.md : HivorrSpacing.sm),
          if (widget.twoCol)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: fields[2]),
                const SizedBox(width: HivorrSpacing.md),
                Expanded(child: fields[3]),
              ],
            )
          else ...<Widget>[
            fields[1],
            const SizedBox(height: HivorrSpacing.sm),
            fields[2],
            const SizedBox(height: HivorrSpacing.sm),
            fields[3],
          ],
          const SizedBox(height: HivorrSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: config.isSaving
                  ? null
                  : () => _save(context, config),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.roleTheme.clientPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                textStyle: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: config.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Configuration'),
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          const _StagedNote(),
        ],
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    AdminConfigProvider config,
  ) async {
    setState(() {
      _feeError = null;
      _daysError = null;
      _maxError = null;
      _minError = null;
    });
    final double? fee = double.tryParse(widget.fee.text.trim());
    final int? days = int.tryParse(widget.escrowDays.text.trim());
    final double? max = double.tryParse(widget.maxBudget.text.trim());
    final double? min = double.tryParse(widget.minBudget.text.trim());
    bool parseFailed = false;
    if (fee == null) {
      _feeError = 'Enter a number.';
      parseFailed = true;
    }
    if (days == null) {
      _daysError = 'Enter whole days.';
      parseFailed = true;
    }
    if (max == null) {
      _maxError = 'Enter a number.';
      parseFailed = true;
    }
    if (min == null) {
      _minError = 'Enter a number.';
      parseFailed = true;
    }
    if (parseFailed) {
      setState(() {});
      return;
    }
    final String? error = await config.saveConfig(
      platformFeePercent: fee!,
      escrowReleaseDays: days!,
      maxJobBudgetUsd: max!,
      minJobBudgetUsd: min!,
    );
    if (!context.mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved.')),
      );
    } else {
      if (error.contains('fee')) {
        setState(() => _feeError = error);
      } else if (error.contains('Escrow')) {
        setState(() => _daysError = error);
      } else if (error.contains('Max')) {
        setState(() => _maxError = error);
      } else if (error.contains('Min')) {
        setState(() => _minError = error);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }
}

/// Platform Toggles card from the reference: label + switch rows that
/// persist through [AdminConfigProvider] (reverting on storage failure).
class _TogglesCard extends StatelessWidget {
  const _TogglesCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AdminConfigProvider config = context.watch<AdminConfigProvider>();

    Widget row({
      required String label,
      required bool value,
      required AdminConfigToggle toggle,
      required bool last,
    }) {
      return Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              Switch(
                value: value,
                activeTrackColor: context.roleTheme.clientPrimary,
                onChanged: config.isSaving
                    ? null
                    : (bool next) =>
                        _flip(context, config, toggle, next),
              ),
            ],
          ),
          if (!last)
            Divider(height: 1, color: colors.outlineVariant),
        ],
      );
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Platform Toggles',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          row(
            label: 'New user registrations',
            value: config.registrationsEnabled,
            toggle: AdminConfigToggle.registrations,
            last: false,
          ),
          row(
            label: 'Job posting',
            value: config.jobPostingEnabled,
            toggle: AdminConfigToggle.jobPosting,
            last: false,
          ),
          row(
            label: 'Automatic KYC approval',
            value: config.autoKycApprovalEnabled,
            toggle: AdminConfigToggle.autoKycApproval,
            last: false,
          ),
          row(
            label: 'Maintenance mode',
            value: config.maintenanceModeEnabled,
            toggle: AdminConfigToggle.maintenanceMode,
            last: true,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          const _StagedNote(),
        ],
      ),
    );
  }

  Future<void> _flip(
    BuildContext context,
    AdminConfigProvider config,
    AdminConfigToggle toggle,
    bool next,
  ) async {
    final String? error = await config.setToggle(toggle, next);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }
}

/// Existing real preference: app language via [LocaleProvider].
class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    LocaleProvider? locales;
    try {
      locales = context.watch<LocaleProvider>();
    } catch (_) {
      locales = null;
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Preferences',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          if (locales == null)
            Text(
              'Language settings are unavailable here.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          else
            for (final Locale locale in locales.supportedLocales) ...<Widget>[
              _CheckRow(
                label: locale.toLanguageTag(),
                selected: locale == locales.currentLocale,
                onTap: () =>
                    unawaited(locales!.setLocale(locale)),
              ),
            ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color:
                  selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Existing real security control: the admin's own password change via
/// [AuthProvider.updatePassword], policy-gated by [PasswordPolicy.supabase].
class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    String name = 'Super Admin';
    String? email;
    try {
      final AuthProvider auth = context.watch<AuthProvider>();
      final session = auth.currentSession;
      final String? full = session?.fullName;
      final String? display = session?.displayName?.trim();
      if (full != null && full.trim().isNotEmpty) {
        name = full.trim();
      } else if (display != null && display.isNotEmpty) {
        name = display;
      }
      email = session?.email;
    } catch (_) {
      // Provider absent in isolated tests — keep fallback.
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Security',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Row(
            children: <Widget>[
              HivorrAvatar(
                name: name,
                size: 40,
                backgroundColor: colors.secondaryContainer,
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (email != null && email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _changePassword(context),
                child: const Text('Change Password'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => const _PasswordDialog(),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  final PasswordPolicy _policy = PasswordPolicy.supabase;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PasswordPolicyResult result =
        _policy.evaluate(_controller.text);
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _controller,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => setState(() {
                _error = null;
              }),
              decoration: InputDecoration(
                labelText: 'New password',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: HivorrSpacing.sm),
            PasswordRequirementsChecklist(
              result: result,
              requirements: _policy.required,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (!result.isValid || _saving)
              ? null
              : () => _submit(context),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() => _saving = true);
    try {
      await context
          .read<AuthProvider>()
          .updatePassword(_controller.text);
      if (!context.mounted) return;
      final String? failure =
          context.read<AuthProvider>().lastError?.message;
      if (failure != null) {
        setState(() {
          _error = failure;
          _saving = false;
        });
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      setState(() {
        _error = 'Could not update the password.';
        _saving = false;
      });
    }
  }
}
