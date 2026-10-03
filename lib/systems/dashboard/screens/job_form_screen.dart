import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:provider/provider.dart';

/// Post-a-job / edit-job form (EP-04-03).
///
/// Creates a draft via `job_create` (or updates via `job_update` when
/// [jobId] is set), then routes to the job detail where the owner publishes.
/// Field validation uses [JobService] validators (title 10–120, description
/// 50–5000); server errors surface via [HivorrSnackbar].
///
/// Visual direction matches the client "Post a New Job" reference:
/// light page background, white [Job Details] + [Budget & Timeline] cards,
/// service-type selector, category chips, escrow note and a fixed-price
/// [Post Job Now] CTA. [Service Type], [Category], [Required Skills],
/// [Experience Level] and [Deadline] are presentation-only — the jobs RPC
/// has no columns for them yet, so they are kept as local state and never
/// sent (taxonomy-binding seam for a future `professionId`/`industryId`
/// mapping). Budget is a single fixed price mapped to both `budgetMin` and
/// `budgetMax` to preserve the existing range backend without data loss.
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key, this.jobId});

  /// When set, the form edits an existing draft/open/paused job.
  final String? jobId;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  static const List<String> _categories = <String>[
    'Development',
    'Design',
    'Trades',
    'Finance',
    'Teaching',
    'Care',
    'Data',
    'Energy',
  ];

  static const List<String> _experienceLevels = <String>[
    'Any',
    'Entry',
    'Intermediate',
    'Expert',
  ];

  static const double _formMaxWidth = 1120;
  static const double _railBreakpoint = 900;
  static const double _railWidth = 360;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _budget = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _skills = TextEditingController();

  String _serviceType = 'Digital';
  String _category = 'Development';
  String _experienceLevel = 'Any';
  DateTime? _deadline;

  bool _saving = false;
  bool _prefilled = false;
  bool _loadRequested = false;

  bool get _editing => widget.jobId != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    _location.dispose();
    _skills.dispose();
    super.dispose();
  }

  void _prefill(Job? job) {
    if (_prefilled || job == null) return;
    _prefilled = true;
    _title.text = job.title;
    _description.text = job.description;
    final double? amount = job.budgetMax ?? job.budgetMin;
    if (amount != null) _budget.text = _trimZero(amount);
    if (job.location != null) _location.text = job.location!;
  }

  String _trimZero(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  void setServiceType(String value) =>
      setState(() => _serviceType = value);

  void setCategory(String value) => setState(() => _category = value);

  void setExperienceLevel(String value) =>
      setState(() => _experienceLevel = value);

  String? _validateTitle(String? value) =>
      (value != null && JobService.validateTitle(value))
      ? null
      : 'Title must be 10 to 120 characters.';

  String? _validateDescription(String? value) =>
      (value != null && JobService.validateDescription(value))
      ? null
      : 'Description must be 50 to 5000 characters.';

  String? _validateBudget(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final double? parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Must be a positive number.';
    return null;
  }

  double? _parseBudget() {
    final String raw = _budget.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? _locationOrNull() {
    final String raw = _location.text.trim();
    return raw.isEmpty ? null : raw;
  }

  String _formatDeadline(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _pickDeadline() async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        _deadline ?? now.add(const Duration(days: 30));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() => _deadline = picked);
    }
  }

  void _snack(String message, HivorrSnackbarVariant variant) {
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(context, message: message, variant: variant),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final JobProvider jobs = context.read<JobProvider>();
      final double? amount = _parseBudget();
      final Job job = _editing
          ? await jobs.update(
              jobId: widget.jobId!,
              title: _title.text.trim(),
              description: _description.text.trim(),
              budgetMin: amount,
              budgetMax: amount,
              location: _locationOrNull(),
            )
          : await jobs.create(
              title: _title.text.trim(),
              description: _description.text.trim(),
              budgetMin: amount,
              budgetMax: amount,
              location: _locationOrNull(),
            );
      if (!mounted) return;
      _snack(
        _editing ? 'Job updated.' : 'Draft job created.',
        HivorrSnackbarVariant.success,
      );
      context.go(RoutePaths.dashboardJobDetail(job.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    if (_editing) {
      if (jobs.selected?.id == widget.jobId) {
        _prefill(jobs.selected);
      } else if (!_loadRequested) {
        _loadRequested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(context.read<JobProvider>().select(widget.jobId!));
          }
        });
      }
    }

    final bool isMobile = context.breakpoint == Breakpoint.mobile;
    final String appBarTitle = _editing ? 'Edit Job' : 'Post a Job';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              title: Text(appBarTitle, style: context.textTheme.titleLarge),
            )
          : null,
      body: MobileSafeBody(
        child: Column(
          children: <Widget>[
            if (!isMobile) _PostJobTopBar(title: appBarTitle),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: MobileCompact.scrollPaddingForBreakpoint(
                  context.breakpoint,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _formMaxWidth,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _PageHeader(editing: _editing),
                          const SizedBox(height: HivorrSpacing.lg),
                          LayoutBuilder(
                            builder:
                                (BuildContext context, BoxConstraints c) {
                              final bool wide =
                                  c.maxWidth >= _railBreakpoint;
                              if (!wide) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _JobDetailsCard(state: this),
                                    const SizedBox(
                                      height: HivorrSpacing.md,
                                    ),
                                    _BudgetCard(state: this),
                                    const SizedBox(
                                      height: HivorrSpacing.md,
                                    ),
                                    const _EscrowCard(),
                                    const SizedBox(
                                      height: HivorrSpacing.lg,
                                    ),
                                    _SubmitButton(
                                      editing: _editing,
                                      saving: _saving,
                                      onSubmit: _submit,
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    flex: 5,
                                    child: _JobDetailsCard(state: this),
                                  ),
                                  const SizedBox(width: HivorrSpacing.lg),
                                  SizedBox(
                                    width: _railWidth,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        _BudgetCard(state: this),
                                        const SizedBox(
                                          height: HivorrSpacing.md,
                                        ),
                                        const _EscrowCard(),
                                        const SizedBox(
                                          height: HivorrSpacing.lg,
                                        ),
                                        _SubmitButton(
                                          editing: _editing,
                                          saving: _saving,
                                          onSubmit: _submit,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop top bar matching the reference: menu tile, page title, bell,
/// Client pill and account avatar.
class _PostJobTopBar extends StatelessWidget {
  const _PostJobTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final roleTheme = context.roleTheme;
    return HivorrDashboardTopBar(
      title: title,
      accentPrimary: roleTheme.clientPrimary,
      accentContainer: roleTheme.clientContainer,
      modeLabel: 'Client',
      initials: 'TV',
      showDot: true,
      onMenu: () {
        final ScaffoldState? scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      onNotifications: () => context.go(RoutePaths.dashboardNotifications),
      onAvatar: () => context.go(RoutePaths.dashboardAccount),
    );
  }
}

/// Page heading from the reference.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          editing ? 'Edit Job' : 'Post a New Job',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          editing
              ? 'Update the details of your job.'
              : 'Find the right professional for your project',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Left card: Job Details.
class _JobDetailsCard extends StatelessWidget {
  const _JobDetailsCard({required this.state});

  final _JobFormScreenState state;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Job Details',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const _FieldLabel(text: 'Job Title', required: true),
          const SizedBox(height: HivorrSpacing.sm),
          _ReferenceField(
            controller: state._title,
            hint: 'Senior React Developer Needed',
            validator: state._validateTitle,
          ),
          const SizedBox(height: HivorrSpacing.md),
          const _FieldLabel(text: 'Service Type', required: true),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _ServiceTypeOption(
                  label: 'Digital',
                  icon: Icons.computer_outlined,
                  selected: state._serviceType == 'Digital',
                  onTap: () => state.setServiceType('Digital'),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: _ServiceTypeOption(
                  label: 'Physical',
                  icon: Icons.handyman_outlined,
                  selected: state._serviceType == 'Physical',
                  onTap: () => state.setServiceType('Physical'),
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.md),
          const _FieldLabel(text: 'Category', required: true),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final String category
                  in _JobFormScreenState._categories)
                _CategoryChip(
                  label: category,
                  selected: state._category == category,
                  onTap: () => state.setCategory(category),
                ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.md),
          const _FieldLabel(text: 'Description', required: true),
          const SizedBox(height: HivorrSpacing.sm),
          _ReferenceField(
            controller: state._description,
            hint: 'Describe requirements, deliverables, and expectations...',
            maxLines: 7,
            validator: state._validateDescription,
          ),
          const SizedBox(height: HivorrSpacing.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final bool stack = c.maxWidth < 420;
              final Widget skills = Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _FieldLabel(text: 'Required Skills'),
                    const SizedBox(height: HivorrSpacing.sm),
                    _ReferenceField(
                      controller: state._skills,
                      hint: 'React, TypeScript...',
                    ),
                  ],
                ),
              );
              final Widget level = Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _FieldLabel(text: 'Experience Level'),
                    const SizedBox(height: HivorrSpacing.sm),
                    _ExperienceDropdown(state: state),
                  ],
                ),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    skills,
                    const SizedBox(height: HivorrSpacing.md),
                    level,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  skills,
                  const SizedBox(width: HivorrSpacing.sm),
                  level,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Right card: Budget & Timeline.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.state});

  final _JobFormScreenState state;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Budget & Timeline',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const _FieldLabel(text: 'Budget', required: true),
          const SizedBox(height: HivorrSpacing.sm),
          _BudgetField(state: state),
          const SizedBox(height: HivorrSpacing.md),
          const _FieldLabel(text: 'Location'),
          const SizedBox(height: HivorrSpacing.sm),
          _ReferenceField(
            controller: state._location,
            hint: 'Remote',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: HivorrSpacing.md),
          const _FieldLabel(text: 'Deadline'),
          const SizedBox(height: HivorrSpacing.sm),
          _DeadlineField(state: state),
        ],
      ),
    );
  }
}

/// White rounded card with the reference soft shadow.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final double radius = context.appExtension.radiusMd + 4;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        children: required
            ? <TextSpan>[
                TextSpan(
                  text: ' *',
                  style:
                      TextStyle(color: context.colorScheme.onSurfaceVariant),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Reference-styled filled input: light fill, 12dp radius, no hairline
/// border, primary focus ring. Token-based — no hardcoded palette.
class _ReferenceField extends StatelessWidget {
  const _ReferenceField({
    required this.controller,
    required this.hint,
    this.validator,
    this.maxLines = 1,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color fill = colors.surfaceContainerHighest.withValues(
      alpha: context.isDarkMode ? 1.0 : 0.45,
    );
    OutlineInputBorder border(Color? side, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: side == null
              ? BorderSide.none
              : BorderSide(color: side, width: width),
        );
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 6 : 1,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: context.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: context.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        filled: true,
        fillColor: fill,
        contentPadding: EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: maxLines > 1 ? HivorrSpacing.md : 15,
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: colors.onSurfaceVariant),
        border: border(null),
        enabledBorder: border(null),
        focusedBorder: border(colors.primary, 1.5),
        errorBorder: border(colors.error),
        focusedErrorBorder: border(colors.error, 1.5),
      ),
    );
  }
}

class _ServiceTypeOption extends StatelessWidget {
  const _ServiceTypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color fill = selected
        ? colors.surface
        : colors.surfaceContainerHighest.withValues(
            alpha: context.isDarkMode ? 1.0 : 0.45,
          );
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Text(
                label,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary
                : colors.surfaceContainerHighest.withValues(
                    alpha: context.isDarkMode ? 1.0 : 0.45,
                  ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExperienceDropdown extends StatelessWidget {
  const _ExperienceDropdown({required this.state});

  final _JobFormScreenState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color fill = colors.surfaceContainerHighest.withValues(
      alpha: context.isDarkMode ? 1.0 : 0.45,
    );
    return DropdownButtonFormField<String>(
      initialValue: state._experienceLevel,
      items: <DropdownMenuItem<String>>[
        for (final String level in _JobFormScreenState._experienceLevels)
          DropdownMenuItem<String>(value: level, child: Text(level)),
      ],
      onChanged: (String? value) {
        if (value != null) state.setExperienceLevel(value);
      },
      style: context.textTheme.bodyLarge,
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: 15,
        ),
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
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Fixed-price budget input: `$ | amount | Fixed`, matching the reference.
class _BudgetField extends StatelessWidget {
  const _BudgetField({required this.state});

  final _JobFormScreenState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color fill = colors.surfaceContainerHighest.withValues(
      alpha: context.isDarkMode ? 1.0 : 0.45,
    );
    OutlineInputBorder border(Color? side, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: side == null
              ? BorderSide.none
              : BorderSide(color: side, width: width),
        );
    return TextFormField(
      controller: state._budget,
      keyboardType: TextInputType.number,
      validator: state._validateBudget,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: context.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: 15,
        ),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: HivorrSpacing.md),
            Text(
              '\$',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Container(
              width: 1,
              height: 24,
              color: colors.outlineVariant,
            ),
            const SizedBox(width: HivorrSpacing.sm),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: HivorrSpacing.md),
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              'Fixed',
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: '3500',
        hintStyle: context.textTheme.bodyLarge?.copyWith(
          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: border(null),
        enabledBorder: border(null),
        focusedBorder: border(colors.primary, 1.5),
        errorBorder: border(colors.error),
        focusedErrorBorder: border(colors.error, 1.5),
      ),
    );
  }
}

class _DeadlineField extends StatelessWidget {
  const _DeadlineField({required this.state});

  final _JobFormScreenState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color fill = colors.surfaceContainerHighest.withValues(
      alpha: context.isDarkMode ? 1.0 : 0.45,
    );
    final String? text = state._deadline == null
        ? null
        : state._formatDeadline(state._deadline!);
    return Semantics(
      button: true,
      label: 'Deadline',
      child: InkWell(
        onTap: state._pickDeadline,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  text ?? 'DD/MM/YYYY',
                  style: text == null
                      ? context.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        )
                      : context.textTheme.bodyLarge,
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: colors.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EscrowCard extends StatelessWidget {
  const _EscrowCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(
          alpha: context.isDarkMode ? 0.35 : 0.45,
        ),
        borderRadius: BorderRadius.circular(
          context.appExtension.radiusMd + 4,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.shield_outlined,
            size: 22,
            color: colors.primary,
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Escrow Protection',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  'Payment held securely until you approve the completed work.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.editing,
    required this.saving,
    required this.onSubmit,
  });

  final bool editing;
  final bool saving;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return HivorrButton(
      label: editing ? 'Save Changes' : 'Post Job Now',
      icon: const Icon(Icons.bolt, size: 20),
      size: HivorrButtonSize.large,
      isExpanded: true,
      isLoading: saving,
      onPressed: saving ? null : () => unawaited(onSubmit()),
    );
  }
}
