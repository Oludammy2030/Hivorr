import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_quotation.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';
import 'package:provider/provider.dart';

/// Hire detail: quotation thread, contract link, lifecycle actions (EP-04-02/03).
///
/// Client: quotation accept, hire cancel (pending), hire complete (on a
/// completed/closed contract), jump to the linked escrow/contract.
/// Professional: quotation propose/withdraw, hire cancel (pending).
class HireDetailScreen extends StatefulWidget {
  const HireDetailScreen({super.key, required this.hireId});

  final String hireId;

  @override
  State<HireDetailScreen> createState() => _HireDetailScreenState();
}

class _HireDetailScreenState extends State<HireDetailScreen> {
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<HireProvider>().select(widget.hireId);

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
    final HireProvider hires = context.watch<HireProvider>();
    final Hire? hire = hires.selected?.id == widget.hireId
        ? hires.selected
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hire Details', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load()),
          ),
        ],
      ),
      body: SafeArea(
        child: hires.isLoading && hire == null
            ? const HivorrLoadingState()
            : hires.lastError != null && hire == null
            ? HivorrErrorState(
                message: 'Could not load hire',
                detail: hires.lastError!.message,
                onRetry: () => unawaited(_load()),
              )
            : hire == null
            ? const HivorrLoadingState()
            : RefreshIndicator(
                onRefresh: _load,
                child: _DetailBody(hire: hire, acting: _acting, onAction: _run),
              ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.hire,
    required this.acting,
    required this.onAction,
  });

  final Hire hire;
  final bool acting;
  final Future<void> Function(
    Future<dynamic> Function(), {
    required String success,
  })
  onAction;

  Future<void> _openThread(BuildContext context, String contractId) async {
    try {
      final conversation = await context
          .read<MessagingProvider>()
          .ensureForContract(contractId);
      if (!context.mounted) return;
      context.go(RoutePaths.dashboardMessageThread(conversation.id));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final String? entityId = context
        .watch<AuthProvider>()
        .currentSession
        ?.entityId;
    final bool isClient = entityId != null && entityId == hire.clientEntityId;
    final String effective = hires.selectedEffectiveStatus ?? hire.liveStatus;
    final JobQuotation? quotation = hires.selectedQuotation;
    final String? contractId = hires.selectedContractId ?? hire.contractId;
    final String? contractStatus = hires.selectedContractStatus;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivorrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        hire.jobTitle ?? 'Hire',
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    HiringStatusBadge(code: effective),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  'Hired ${HivorrFormatters.relative(hire.hiredAt)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (contractId != null) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.sm),
                  Text(
                    'Contract ${contractStatus ?? ''}'.trim(),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.sm,
            children: <Widget>[
              HivorrButton(
                label: 'View Job',
                variant: HivorrButtonVariant.outline,
                onPressed: () =>
                    context.go(RoutePaths.dashboardJobDetail(hire.jobId)),
              ),
              if (contractId != null)
                HivorrButton(
                  label: 'View Contract',
                  variant: HivorrButtonVariant.outline,
                  onPressed: () => context.go('/finance/escrow/$contractId'),
                ),
              if (contractId != null)
                HivorrButton(
                  label: 'Message',
                  variant: HivorrButtonVariant.outline,
                  onPressed: acting
                      ? null
                      : () => _openThread(context, contractId),
                ),
              if (hire.isPending)
                HivorrButton(
                  label: 'Cancel Hire',
                  variant: HivorrButtonVariant.outline,
                  onPressed: acting
                      ? null
                      : () => onAction(
                          () =>
                              context.read<HireProvider>().cancelHire(hire.id),
                          success: 'Hire cancelled.',
                        ),
                ),
              if (isClient && effective == 'completed')
                HivorrButton(
                  label: 'Complete Hire',
                  onPressed: acting
                      ? null
                      : () => onAction(
                          () => context.read<HireProvider>().completeHire(
                            hire.id,
                          ),
                          success: 'Hire completed.',
                        ),
                ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xl),
          const HivorrSectionHeader(title: 'Quotation'),
          _QuotationCard(
            quotation: quotation,
            isClient: isClient,
            acting: acting,
            onAction: onAction,
            hire: hire,
          ),
        ],
      ),
    );
  }
}

class _QuotationCard extends StatelessWidget {
  const _QuotationCard({
    required this.quotation,
    required this.isClient,
    required this.acting,
    required this.onAction,
    required this.hire,
  });

  final JobQuotation? quotation;
  final bool isClient;
  final bool acting;
  final Future<void> Function(
    Future<dynamic> Function(), {
    required String success,
  })
  onAction;
  final Hire hire;

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.read<HireProvider>();
    if (quotation == null) {
      return HivorrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              isClient
                  ? 'Hired on the application quote.'
                  : 'Hired on your application quote.',
              style: context.textTheme.bodyMedium,
            ),
            if (!isClient) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              HivorrButton(
                label: 'Propose New Quotation',
                variant: HivorrButtonVariant.outline,
                onPressed: acting
                    ? null
                    : () => _QuoteSheet.show(
                        context,
                        applicationId: hire.applicationId,
                      ),
              ),
            ],
          ],
        ),
      );
    }
    final JobQuotation quote = quotation!;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${quote.currencyCode} ${HivorrFormatters.number(quote.proposedAmount, decimals: 0)}',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              HiringStatusBadge(code: quote.status),
            ],
          ),
          if (quote.message != null && quote.message!.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Text(quote.message!, style: context.textTheme.bodySmall),
          ],
          Text(
            'Revision ${quote.revisionNumber}'
            '${quote.durationDays == null ? '' : ' · ${quote.durationDays} days'}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.sm,
            children: <Widget>[
              if (isClient && quote.isLive)
                HivorrButton(
                  label: 'Accept Quotation',
                  onPressed: acting
                      ? null
                      : () => onAction(
                          () => hires.acceptQuotation(quote.id),
                          success: 'Quotation accepted.',
                        ),
                ),
              if (!isClient && quote.isLive)
                HivorrButton(
                  label: 'Withdraw',
                  variant: HivorrButtonVariant.outline,
                  onPressed: acting
                      ? null
                      : () => onAction(
                          () => hires.withdrawQuotation(quote.id),
                          success: 'Quotation withdrawn.',
                        ),
                ),
              if (!isClient)
                HivorrButton(
                  label: 'Revise',
                  variant: HivorrButtonVariant.outline,
                  onPressed: acting
                      ? null
                      : () => _QuoteSheet.show(
                          context,
                          applicationId: quote.applicationId,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet quotation propose/revise form.
class _QuoteSheet extends StatefulWidget {
  const _QuoteSheet({required this.applicationId});

  final String applicationId;

  static void show(BuildContext context, {required String applicationId}) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        // Sheet context (not the outer one): keyboard height stays correct
        // across rotation/fold while the sheet is open.
        builder: (BuildContext sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _QuoteSheet(applicationId: applicationId),
        ),
      ),
    );
  }

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _amount.dispose();
    _duration.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await context.read<HireProvider>().proposeQuotation(
        applicationId: widget.applicationId,
        amount: double.parse(_amount.text.trim()),
        durationDays: _duration.text.trim().isEmpty
            ? null
            : int.tryParse(_duration.text.trim()),
        message: _message.text.trim().isEmpty ? null : _message.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Quotation proposed.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
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
                'Propose quotation',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: HivorrSpacing.md),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (NGN)',
                  border: OutlineInputBorder(),
                ),
                validator: (String? v) {
                  final double? parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Must be greater than zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: HivorrSpacing.md),
              TextFormField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration in days (optional)',
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
              const SizedBox(height: HivorrSpacing.md),
              TextFormField(
                controller: _message,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: HivorrSpacing.lg),
              HivorrButton(
                label: 'Propose',
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
