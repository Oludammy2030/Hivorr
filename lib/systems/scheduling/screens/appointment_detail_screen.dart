import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/providers/scheduling_provider.dart';
import 'package:hivorr/shared/components/hivorr_bottom_sheet.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';
import 'package:hivorr/systems/scheduling/widgets/appointment_status_badge.dart';
import 'package:hivorr/systems/scheduling/widgets/appointment_timeline.dart';
import 'package:hivorr/systems/scheduling/widgets/scheduling_write_cta_panel.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

/// Appointment detail screen (EP-03-14 §8 D9).
///
/// `GET /appointments/:id`. Header ([AppointmentStatusBadge] + window via
/// [HivorrFormatters.dateTime] + participants + `View contract` link) +
/// [AppointmentTimeline] + [SchedulingWriteCtaPanel] (role-gated
/// reschedule/cancel from the authoritative row; stranger/terminal paths
/// render the guidance card). Reschedule opens a bottom-sheet
/// (date + start/end pickers, one `uuid v4` key reused across retry);
/// cancel confirms via [HivorrDialog] with an optional `≤500` reason.
/// `PLT005` collision renders the conflict state with `Pick another time`.
/// Enforcement stays server-side (`AGENT.md` Rule 4). Tokens only (Rule 5).
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  /// The `appointments.id` to display.
  final String appointmentId;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  bool _busy = false;
  bool _initialized = false;

  /// Template timezone for the appointment's slot (best-effort caption).
  String? _slotTimezone;
  bool _slotTimezoneRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            context
                .read<SchedulingProvider>()
                .select(widget.appointmentId)
                .then((_) {
                  if (!mounted) return;
                  final Appointment? selected = context
                      .read<SchedulingProvider>()
                      .selected;
                  if (selected != null) unawaited(_loadSlotTimezone(selected));
                }),
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(AppointmentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointmentId != widget.appointmentId) {
      _slotTimezone = null;
      _slotTimezoneRequested = false;
    }
  }

  /// Resolves the template timezone for the appointment's slot (display hint
  /// only — `timestamptz` remains truth; failures stay silent by design).
  Future<void> _loadSlotTimezone(Appointment appointment) async {
    final String? slotId = appointment.slotId;
    if (slotId == null || _slotTimezoneRequested) return;
    _slotTimezoneRequested = true;
    try {
      final List<AvailabilitySlot> slots = await context
          .read<SchedulingProvider>()
          .fetchSlots(entityId: appointment.professionalEntityId);
      if (!mounted) return;
      for (final AvailabilitySlot slot in slots) {
        if (slot.id == slotId) {
          setState(() => _slotTimezone = slot.timezone);
          return;
        }
      }
    } on Object {
      // Best-effort caption — the window itself is already authoritative.
    }
  }

  /// Viewer entity id when a session is resolvable (`null` otherwise — role
  /// captions hide and CTA gating stays purely server-enforced).
  String? get _viewerId {
    try {
      return Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentSession?.entityId;
    } on Object {
      return null;
    }
  }

  Future<void> _run(
    Future<Appointment> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: successMessage,
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final bool taken = e.code == 'PLT005';
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: taken
              ? 'Slot taken. Pick another time.'
              : e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReschedule(Appointment appointment) async {
    final _RescheduleResult? result =
        await HivorrBottomSheet.show<_RescheduleResult>(
          context: context,
          title: 'Reschedule appointment',
          child: _RescheduleSheet(initialStart: appointment.startsAt),
        );
    if (result == null || !mounted) return;
    await _run(
      () => context.read<SchedulingProvider>().reschedule(
        appointment.id,
        newStartsAt: result.startsAt,
        newEndsAt: result.endsAt,
        idempotencyKey: const Uuid().v4(),
      ),
      successMessage: 'Appointment rescheduled.',
    );
  }

  Future<void> _confirmCancel(Appointment appointment) async {
    final TextEditingController reasonController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => HivorrDialog(
        title: 'Cancel appointment?',
        content: HivorrTextField(
          controller: reasonController,
          label: 'Reason (optional)',
          hint: 'Why is this appointment cancelled?',
          maxLines: 3,
          maxLength: 500,
        ),
        actions: <Widget>[
          HivorrButton(
            label: 'Keep',
            onPressed: () => Navigator.of(context).pop(false),
            variant: HivorrButtonVariant.text,
          ),
          HivorrButton(
            label: 'Cancel appointment',
            onPressed: () => Navigator.of(context).pop(true),
            variant: HivorrButtonVariant.primary,
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (confirmed != true || !mounted) return;
    final String reason = reasonController.text.trim();
    await _run(
      () => context.read<SchedulingProvider>().cancel(
        appointment.id,
        reason: reason.isEmpty ? null : reason,
      ),
      successMessage: 'Appointment cancelled.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: HivorrContentPane(
        child: Consumer<SchedulingProvider>(
          builder: (BuildContext context, SchedulingProvider provider, _) {
            switch (provider.loadState) {
              case SchedulingLoadState.loading:
                return const HivorrLoadingState(
                  message: 'Loading appointment…',
                );
              case SchedulingLoadState.idle:
                return HivorrErrorState(
                  message: 'Appointment not loaded',
                  onRetry: () => unawaited(
                    provider.select(widget.appointmentId),
                  ),
                );
              case SchedulingLoadState.loaded:
                final Appointment? appointment = provider.selected;
                if (appointment == null) {
                  return const HivorrEmptyState(
                    title: 'Appointment not found',
                    subtitle:
                        'It may have been removed or you may not have access.',
                  );
                }
                // Viewer identity is affordance-only; the server enforces
                // participation with identical `PLT004`.
                return RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: _DetailBody(
                    appointment: appointment,
                    busy: _busy,
                    slotTimezone: _slotTimezone,
                    viewerId: _viewerId,
                    onReschedule: () => unawaited(
                      _openReschedule(appointment),
                    ),
                    onCancel: () => unawaited(
                      _confirmCancel(appointment),
                    ),
                    onFileDispute: () => context.push(
                      RoutePaths.disputesFile(appointment.contractId),
                    ),
                  ),
                );
              case SchedulingLoadState.error:
                final ApiException? error = provider.lastError;
                if (error?.kind == ApiExceptionKind.notFound) {
                  return const HivorrEmptyState(
                    title: 'Appointment not found',
                    subtitle:
                        'It may have been removed or you may not have access.',
                  );
                }
                return HivorrErrorState(
                  message: 'Could not load appointment',
                  detail: error?.message,
                  onRetry: () => unawaited(
                    provider.select(widget.appointmentId),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.appointment,
    required this.busy,
    this.slotTimezone,
    this.viewerId,
    required this.onReschedule,
    required this.onCancel,
    required this.onFileDispute,
  });

  final Appointment appointment;
  final bool busy;

  /// Template timezone caption (`null` while unresolved — best-effort).
  final String? slotTimezone;

  /// Viewer entity id (`null` when no session is resolvable).
  final String? viewerId;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback onFileDispute;

  @override
  Widget build(BuildContext context) {
    final bool actionable =
        appointment.status == 'pending' || appointment.status == 'confirmed';
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
      children: <Widget>[
        HivorrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      HivorrFormatters.date(appointment.startsAt.toLocal()),
                      style: context.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppointmentStatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${HivorrFormatters.dateTime(appointment.startsAt.toLocal())} → ${HivorrFormatters.time(appointment.endsAt.toLocal())}',
                style: context.textTheme.titleMedium,
              ),
              if (viewerId != null &&
                  (viewerId == appointment.clientEntityId ||
                      viewerId == appointment.professionalEntityId))
                Text(
                  viewerId == appointment.clientEntityId
                      ? 'You are the client'
                      : 'You are the professional',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (slotTimezone != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Times shown in $slotTimezone',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.push(
                  RoutePaths.contractDetail(appointment.contractId),
                ),
                child: const Text('View contract'),
              ),
            ],
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Consumer<SchedulingProvider>(
          builder:
              (BuildContext context, SchedulingProvider provider, _) =>
                  AppointmentTimeline(events: provider.selectedEvents),
        ),
        const SizedBox(height: HivorrSpacing.md),
        SchedulingWriteCtaPanel(
          writeAvailable: actionable,
          guidanceMessage: actionable
              ? null
              : 'This appointment is ${appointment.status} and can no longer be changed.',
          onReschedule: actionable ? onReschedule : null,
          onCancel: actionable ? onCancel : null,
          onFileDispute: onFileDispute,
          isBusy: busy,
        ),
      ],
    );
  }
}

class _RescheduleResult {
  _RescheduleResult({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.initialStart});

  final DateTime initialStart;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    final DateTime local = widget.initialStart.toLocal().add(
      const Duration(days: 1),
    );
    _day = DateTime(local.year, local.month, local.day);
    _start = TimeOfDay(
      hour: widget.initialStart.toLocal().hour,
      minute: widget.initialStart.toLocal().minute,
    );
    final DateTime end = widget.initialStart.toLocal().add(
      const Duration(hours: 1),
    );
    _end = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  DateTime _asLocal(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  Future<void> _pickDay() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  void _submit() {
    final DateTime startsAt = _asLocal(_day, _start);
    final DateTime endsAt = _asLocal(_day, _end);
    if (!SchedulingService.validateWindow(startsAt, endsAt)) {
      setState(
        () => _error = 'Pick a future window of at most 24 hours.',
      );
      return;
    }
    Navigator.of(context).pop(
      _RescheduleResult(startsAt: startsAt, endsAt: endsAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrButton(
          label: HivorrFormatters.date(_day),
          onPressed: () => unawaited(_pickDay()),
          variant: HivorrButtonVariant.outline,
          isExpanded: true,
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: HivorrButton(
                label:
                    '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
                onPressed: () => unawaited(_pickTime(true)),
                variant: HivorrButtonVariant.outline,
                isExpanded: true,
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: HivorrButton(
                label:
                    '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
                onPressed: () => unawaited(_pickTime(false)),
                variant: HivorrButtonVariant.outline,
                isExpanded: true,
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            _error!,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: HivorrSpacing.md),
        HivorrButton(
          label: 'Confirm new time',
          onPressed: _submit,
          variant: HivorrButtonVariant.primary,
          isExpanded: true,
        ),
      ],
    );
  }
}
