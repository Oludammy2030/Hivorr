import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';
import 'package:provider/provider.dart';

/// Job detail with role-aware actions (EP-04-03).
///
/// Owner: publish/pause/resume/edit/cancel/complete + applications inbox
/// (shortlist/reject/hire, quotation accept). Professional: job info + apply
/// CTA + own application status (withdraw, quotation propose). Non-open jobs
/// resolve through the same screen for owners and applicants (no oracle).
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<JobProvider>().select(widget.jobId);

  void _snack(String message, HivorrSnackbarVariant variant) {
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(context, message: message, variant: variant),
    );
  }

  Future<void> _run(
    Future<dynamic> Function() action, {
    required String success,
  }) async {
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      _snack(success, HivorrSnackbarVariant.success);
      unawaited(_load());
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final Job? job = jobs.selected?.id == widget.jobId ? jobs.selected : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Job Details', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load()),
          ),
        ],
      ),
      body: SafeArea(
        child: jobs.isLoading && job == null
            ? const HivorrLoadingState()
            : jobs.lastError != null && job == null
            ? HivorrErrorState(
                message: 'Could not load job',
                detail: jobs.lastError!.message,
                onRetry: () => unawaited(_load()),
              )
            : job == null
            ? const HivorrLoadingState()
            : RefreshIndicator(
                onRefresh: _load,
                child: _DetailBody(job: job, acting: _acting, onAction: _run),
              ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.job,
    required this.acting,
    required this.onAction,
  });

  final Job job;
  final bool acting;
  final Future<void> Function(
    Future<dynamic> Function(), {
    required String success,
  })
  onAction;

  @override
  Widget build(BuildContext context) {
    // Ownership is authoritative: the job owner is the auth entity.
    final String? entityId = context
        .watch<AuthProvider>()
        .currentSession
        ?.entityId;
    final bool isOwner =
        entityId != null &&
        entityId.isNotEmpty &&
        entityId == job.clientEntityId;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderCard(job: job),
          const SizedBox(height: HivorrSpacing.md),
          if (isOwner)
            _OwnerActions(job: job, acting: acting, onAction: onAction)
          else
            _ApplicantPanel(job: job, acting: acting, onAction: onAction),
          const SizedBox(height: HivorrSpacing.xl),
          if (isOwner) ...<Widget>[
            const HivorrSectionHeader(title: 'Applications'),
            _ApplicationsInbox(acting: acting, onAction: onAction),
          ] else ...<Widget>[
            const HivorrSectionHeader(title: 'About this job'),
            _MetaCard(job: job),
          ],
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  job.title,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              HiringStatusBadge(code: job.status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(job.description, style: context.textTheme.bodyMedium),
          const SizedBox(height: HivorrSpacing.md),
          Wrap(
            spacing: HivorrSpacing.md,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              if (job.budgetMin != null || job.budgetMax != null)
                Text(
                  _budget(job),
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.primary,
                  ),
                ),
              if (job.location != null && job.location!.isNotEmpty)
                Text(job.location!, style: context.textTheme.bodySmall),
              Text(
                '${job.applicationsCount} applications',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Posted ${HivorrFormatters.relative(job.createdAt)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _budget(Job job) {
    String compact(double v) => HivorrFormatters.number(v, decimals: 0);
    if (job.budgetMin != null && job.budgetMax != null) {
      return '${job.currencyCode} ${compact(job.budgetMin!)} – ${compact(job.budgetMax!)}';
    }
    final double? single = job.budgetMax ?? job.budgetMin;
    return single == null
        ? job.currencyCode
        : '${job.currencyCode} ${compact(single)}';
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Row(label: 'Status', value: job.status),
          _Row(label: 'Currency', value: job.currencyCode),
          if (job.postedAt != null)
            _Row(
              label: 'Published',
              value: HivorrFormatters.date(job.postedAt!),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: context.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({
    required this.job,
    required this.acting,
    required this.onAction,
  });

  final Job job;
  final bool acting;
  final Future<void> Function(
    Future<dynamic> Function(), {
    required String success,
  })
  onAction;

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.read<JobProvider>();
    final List<Widget> buttons = <Widget>[];
    void add(
      String label,
      Future<Job> Function() action,
      String success, {
      bool primary = false,
    }) {
      buttons.add(
        _ActionButton(
          label: label,
          primary: primary,
          enabled: !acting,
          onTap: () => onAction(action, success: success),
        ),
      );
    }

    if (job.status == 'draft') {
      add(
        'Publish Job',
        () => jobs.publish(job.id),
        'Job published.',
        primary: true,
      );
      buttons.add(
        _ActionButton(
          label: 'Edit',
          enabled: !acting,
          onTap: () => context.go(RoutePaths.dashboardJobEdit(job.id)),
        ),
      );
    }
    if (job.status == 'open') {
      add('Pause', () => jobs.pause(job.id), 'Job paused.');
      buttons.add(
        _ActionButton(
          label: 'Edit',
          enabled: !acting,
          onTap: () => context.go(RoutePaths.dashboardJobEdit(job.id)),
        ),
      );
    }
    if (job.status == 'paused') {
      add('Resume', () => jobs.resume(job.id), 'Job resumed.', primary: true);
    }
    if (job.status == 'awarded') {
      add(
        'Mark Complete',
        () => jobs.complete(job.id),
        'Job completed.',
        primary: true,
      );
    }
    if (job.isEditable) {
      add('Cancel Job', () => jobs.cancel(job.id), 'Job cancelled.');
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: buttons,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return HivorrButton(
      label: label,
      variant: primary
          ? HivorrButtonVariant.primary
          : HivorrButtonVariant.outline,
      onPressed: enabled ? onTap : null,
    );
  }
}

class _ApplicantPanel extends StatelessWidget {
  const _ApplicantPanel({
    required this.job,
    required this.acting,
    required this.onAction,
  });

  final Job job;
  final bool acting;
  final Future<void> Function(
    Future<dynamic> Function(), {
    required String success,
  })
  onAction;

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final JobApplication? mine = jobs.myApplication;

    if (mine != null) {
      return HivorrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Your application',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                HiringStatusBadge(code: mine.status),
              ],
            ),
            const SizedBox(height: HivorrSpacing.sm),
            if (mine.quotedAmount != null)
              Text(
                '${mine.currencyCode} ${HivorrFormatters.number(mine.quotedAmount!, decimals: 0)}',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: HivorrSpacing.sm),
            if (mine.isWithdrawable)
              HivorrButton(
                label: 'Withdraw Application',
                variant: HivorrButtonVariant.outline,
                onPressed: acting
                    ? null
                    : () => onAction(
                        () => jobs.withdrawApplication(mine.id),
                        success: 'Application withdrawn.',
                      ),
              ),
          ],
        ),
      );
    }

    if (!job.isOpen) {
      return HivorrEmptyState(
        title: 'Not accepting applications',
        subtitle: 'This job is ${job.status} and is no longer open.',
      );
    }

    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Interested in this job?',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Submit an application with your quote. The client reviews all applications before shortlisting.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrButton(
            label: 'Apply to Job',
            isExpanded: true,
            onPressed: acting
                ? null
                : () => _ApplySheet.show(context, jobId: job.id),
          ),
        ],
      ),
    );
  }
}

class _ApplicationsInbox extends StatelessWidget {
  const _ApplicationsInbox({required this.acting, required this.onAction});

  final bool acting;
  final Future<void> Function(
    Future<dynamic> Function(), {
    required String success,
  })
  onAction;

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.read<HireProvider>();
    final List<JobApplication> inbox = jobs.applications;

    if (jobs.isLoading && inbox.isEmpty) return const HivorrLoadingState();
    if (inbox.isEmpty) {
      return const HivorrEmptyState(
        title: 'No applications yet',
        subtitle:
            'Applications from professionals will appear here once your job is open.',
      );
    }
    return Column(
      children: <Widget>[
        for (final JobApplication application in inbox)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: HivorrCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          application.quotedAmount == null
                              ? 'Application'
                              : '${application.currencyCode} ${HivorrFormatters.number(application.quotedAmount!, decimals: 0)}'
                                    '${application.durationDays == null ? '' : ' · ${application.durationDays}d'}',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      HiringStatusBadge(code: application.status),
                    ],
                  ),
                  const SizedBox(height: HivorrSpacing.xs),
                  Text(
                    application.coverNote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  if (application.status == 'submitted')
                    Wrap(
                      spacing: HivorrSpacing.sm,
                      children: <Widget>[
                        _ActionButton(
                          label: 'Shortlist',
                          primary: true,
                          enabled: !acting,
                          onTap: () => onAction(
                            () => jobs.shortlistApplication(application.id),
                            success: 'Application shortlisted.',
                          ),
                        ),
                        _ActionButton(
                          label: 'Reject',
                          enabled: !acting,
                          onTap: () => onAction(
                            () => jobs.rejectApplication(application.id),
                            success: 'Application rejected.',
                          ),
                        ),
                      ],
                    ),
                  if (application.status == 'shortlisted')
                    Wrap(
                      spacing: HivorrSpacing.sm,
                      children: <Widget>[
                        _ActionButton(
                          label: 'Hire',
                          primary: true,
                          enabled: !acting,
                          onTap: () => onAction(
                            () => hires
                                .acceptHire(application.id)
                                .then((_) => jobs.select(application.jobId)),
                            success: 'Professional hired.',
                          ),
                        ),
                        _ActionButton(
                          label: 'Reject',
                          enabled: !acting,
                          onTap: () => onAction(
                            () => jobs.rejectApplication(application.id),
                            success: 'Application rejected.',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom-sheet application form: cover note + quote + duration.
class _ApplySheet extends StatefulWidget {
  const _ApplySheet({required this.jobId});

  final String jobId;

  static void show(BuildContext context, {required String jobId}) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _ApplySheet(jobId: jobId),
        ),
      ),
    );
  }

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cover = TextEditingController();
  final TextEditingController _quote = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _cover.dispose();
    _quote.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await context.read<JobProvider>().apply(
        jobId: widget.jobId,
        coverNote: _cover.text.trim(),
        quotedAmount: _quote.text.trim().isEmpty
            ? null
            : double.tryParse(_quote.text.trim()),
        durationDays: _duration.text.trim().isEmpty
            ? null
            : int.tryParse(_duration.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Application submitted.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
      unawaited(context.read<JobProvider>().select(widget.jobId));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Apply to this job',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: HivorrSpacing.md),
              TextFormField(
                controller: _cover,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Cover note',
                  hintText: 'Experience, approach, availability…',
                  border: OutlineInputBorder(),
                ),
                validator: (String? v) => (v != null && v.trim().length >= 20)
                    ? null
                    : 'Cover note must be 20 to 2000 characters.',
              ),
              const SizedBox(height: HivorrSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _quote,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quote (NGN)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final double? parsed = double.tryParse(v.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Must be greater than zero.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Days',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final int? parsed = int.tryParse(v.trim());
                        if (parsed == null || parsed < 1) {
                          return 'At least 1 day.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.lg),
              HivorrButton(
                label: 'Submit Application',
                isExpanded: true,
                isLoading: _sending,
                onPressed: _sending ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
