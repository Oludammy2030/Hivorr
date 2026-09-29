import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/components/hivorr_form_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:provider/provider.dart';

/// Post-a-job / edit-job form (EP-04-03).
///
/// Creates a draft via `job_create` (or updates via `job_update` when
/// [jobId] is set), then routes to the job detail where the owner publishes.
/// Field validation uses [HivorrFormField] validators mirroring the server
/// CHECKs through [JobService] validators (same pattern as the service
/// listing form); server errors surface via [HivorrSnackbar].
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key, this.jobId});

  /// When set, the form edits an existing draft/open/paused job.
  final String? jobId;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _budgetMin = TextEditingController();
  final TextEditingController _budgetMax = TextEditingController();
  final TextEditingController _location = TextEditingController();
  bool _saving = false;
  bool _prefilled = false;
  bool _loadRequested = false;

  bool get _editing => widget.jobId != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _budgetMin.dispose();
    _budgetMax.dispose();
    _location.dispose();
    super.dispose();
  }

  void _prefill(Job? job) {
    if (_prefilled || job == null) return;
    _prefilled = true;
    _title.text = job.title;
    _description.text = job.description;
    if (job.budgetMin != null) _budgetMin.text = _trimZero(job.budgetMin!);
    if (job.budgetMax != null) _budgetMax.text = _trimZero(job.budgetMax!);
    if (job.location != null) _location.text = job.location!;
  }

  String _trimZero(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  String? _validateTitle(String? value) =>
      (value != null && JobService.validateTitle(value))
      ? null
      : 'Title must be 10 to 120 characters.';

  String? _validateDescription(String? value) =>
      (value != null && JobService.validateDescription(value))
      ? null
      : 'Description must be 50 to 5000 characters.';

  String? _validateBudget(String? value, {required bool isMax}) {
    if (value == null || value.trim().isEmpty) return null;
    final double? parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Must be a positive number.';
    if (isMax) {
      final double? min = _parseBudget(_budgetMin);
      if (min != null && parsed < min) return 'Must be at least the minimum.';
    }
    return null;
  }

  double? _parseBudget(TextEditingController controller) {
    final String raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? _locationOrNull() {
    final String raw = _location.text.trim();
    return raw.isEmpty ? null : raw;
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
      final Job job = _editing
          ? await jobs.update(
              jobId: widget.jobId!,
              title: _title.text.trim(),
              description: _description.text.trim(),
              budgetMin: _parseBudget(_budgetMin),
              budgetMax: _parseBudget(_budgetMax),
              location: _locationOrNull(),
            )
          : await jobs.create(
              title: _title.text.trim(),
              description: _description.text.trim(),
              budgetMin: _parseBudget(_budgetMin),
              budgetMax: _parseBudget(_budgetMax),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? 'Edit Job' : 'Post a Job',
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _editing
                      ? 'Update the details of your job.'
                      : 'Describe the work you need done. Your job saves as a draft — you publish it when ready.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.lg),
                HivorrFormField(
                  controller: _title,
                  label: 'Job title',
                  hint: 'e.g. Fix my kitchen plumbing issue',
                  maxLength: 120,
                  validator: _validateTitle,
                ),
                const SizedBox(height: HivorrSpacing.md),
                HivorrFormField(
                  controller: _description,
                  label: 'Description',
                  hint: 'Scope, materials, timeline, access details…',
                  maxLines: 6,
                  maxLength: 5000,
                  validator: _validateDescription,
                ),
                const SizedBox(height: HivorrSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: HivorrFormField(
                        controller: _budgetMin,
                        label: 'Min budget (NGN)',
                        hint: 'Optional',
                        keyboardType: TextInputType.number,
                        validator: (String? v) =>
                            _validateBudget(v, isMax: false),
                      ),
                    ),
                    const SizedBox(width: HivorrSpacing.md),
                    Expanded(
                      child: HivorrFormField(
                        controller: _budgetMax,
                        label: 'Max budget (NGN)',
                        hint: 'Optional',
                        keyboardType: TextInputType.number,
                        validator: (String? v) =>
                            _validateBudget(v, isMax: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.md),
                HivorrFormField(
                  controller: _location,
                  label: 'Location',
                  hint: 'e.g. Ikeja, Lagos (optional)',
                ),
                const SizedBox(height: HivorrSpacing.xl),
                HivorrButton(
                  label: _editing ? 'Save Changes' : 'Create Draft Job',
                  isExpanded: true,
                  isLoading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
