import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/providers/scheduling_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';
import 'package:hivorr/systems/scheduling/widgets/slot_picker_sheet.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

/// Appointment booking screen (EP-03-14 §8 D8).
///
/// `GET /contracts/:id/appointments/new`. Contract context header + month
/// [CalendarDatePicker] (past dates disabled client-side; server `PLT003`
/// stays authoritative) + day slot grid derived from `availability_list`
/// mapped to concrete `timestamptz` + manual start/end fallback (ad-hoc
/// `slot_id=NULL`) + draft-validated `Confirm booking`. One `uuid v4`
/// idempotency key per gesture (reused across retry); double-tap reuses the
/// in-flight key. Overlap surfaces `PLT005` as [HivorrErrorState] with
/// `Pick another time` (grid preserved). All authoritative checks stay
/// server-side (`AGENT.md` Rule 4). Tokens only (Rule 5).
class AppointmentBookScreen extends StatefulWidget {
  const AppointmentBookScreen({super.key, required this.contractId});

  /// The `service_contracts.id` the appointment is booked under.
  final String contractId;

  @override
  State<AppointmentBookScreen> createState() => _AppointmentBookScreenState();
}

class _AppointmentBookScreenState extends State<AppointmentBookScreen> {
  DateTime _day = DateTime.now().add(const Duration(days: 1));
  DateTime? _pickedStart;
  TimeOfDay _manualStart = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _manualEnd = const TimeOfDay(hour: 11, minute: 0);
  bool _useManual = false;
  bool _loadingSlots = true;
  ApiException? _slotsError;
  bool _confirming = false;
  ApiException? _confirmError;
  bool _slotTaken = false;
  String? _idempotencyKey;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadSlots());
      });
    }
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    try {
      // Template discovery is best-effort: without a contract context the
      // manual window fallback still books ad-hoc (`slot_id=NULL`).
      await context.read<SchedulingProvider>().loadSlots();
      if (!mounted) return;
      setState(() => _loadingSlots = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _slotsError = e.kind == ApiExceptionKind.notFound ? null : e;
      });
    }
  }

  DateTime _asLocal(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  Future<void> _pickManualTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _manualStart : _manualEnd,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _manualStart = picked;
        } else {
          _manualEnd = picked;
        }
        _useManual = true;
        _pickedStart = null;
        _idempotencyKey = null;
        _slotTaken = false;
      });
    }
  }

  Future<void> _confirm() async {
    final DateTime startsAt;
    final DateTime endsAt;
    if (_useManual || _pickedStart == null) {
      startsAt = _asLocal(_day, _manualStart);
      endsAt = _asLocal(_day, _manualEnd);
    } else {
      startsAt = _pickedStart!;
      endsAt = _pickedStart!.add(const Duration(hours: 1));
    }
    if (!SchedulingService.validateWindow(startsAt, endsAt)) {
      setState(() {
        _confirmError = const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'Pick a future window of at most 24 hours.',
          code: 'PLT003',
        );
      });
      return;
    }
    // One key per gesture: minted once, reused across retry so a transient
    // failure never books twice.
    _idempotencyKey ??= const Uuid().v4();
    setState(() {
      _confirming = true;
      _confirmError = null;
      _slotTaken = false;
    });
    try {
      final created = await context.read<SchedulingProvider>().book(
        contractId: widget.contractId,
        startsAt: startsAt,
        endsAt: endsAt,
        idempotencyKey: _idempotencyKey,
      );
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _idempotencyKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Appointment booked.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
      unawaited(context.push(RoutePaths.appointmentDetail(created.id)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _confirmError = e;
        _slotTaken = e.code == 'PLT005';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: HivorrContentPane(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
          children: <Widget>[
            HivorrCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Contract',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Booking under contract …${widget.contractId.length > 6 ? widget.contractId.substring(widget.contractId.length - 6) : widget.contractId}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            HivorrCard(
              child: CalendarDatePicker(
                initialDate: _day,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                onDateChanged: (DateTime day) => setState(() {
                  _day = day;
                  _pickedStart = null;
                  _useManual = false;
                  _idempotencyKey = null;
                  _slotTaken = false;
                }),
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            _SlotSection(
              loading: _loadingSlots,
              error: _slotsError,
              day: _day,
              picked: _pickedStart,
              slotTaken: _slotTaken,
              onRetrySlots: () => unawaited(_loadSlots()),
              onPick: (DateTime window) => setState(() {
                _pickedStart = window;
                _useManual = false;
                _idempotencyKey = null;
                _slotTaken = false;
              }),
              onManual: (TimeOfDay start, TimeOfDay end) => setState(() {
                _manualStart = start;
                _manualEnd = end;
                _useManual = true;
                _pickedStart = null;
                _idempotencyKey = null;
              }),
              onPickManualTime: _pickManualTime,
              manualStart: _manualStart,
              manualEnd: _manualEnd,
              useManual: _useManual,
            ),
            const SizedBox(height: HivorrSpacing.md),
            if (_confirmError != null)
              _slotTaken
                  ? HivorrErrorState(
                      message:
                          _confirmError!.message.isNotEmpty
                          ? _confirmError!.message
                          : 'Slot taken. Pick another time.',
                      actionLabel: 'Pick another time',
                      onAction: () => setState(() {
                        _slotTaken = false;
                        _confirmError = null;
                        _pickedStart = null;
                        _idempotencyKey = null;
                      }),
                      onRetry: () => unawaited(_confirm()),
                    )
                  : HivorrErrorState(
                      message: 'Could not book appointment',
                      detail: _confirmError!.message,
                      onRetry: () => unawaited(_confirm()),
                    ),
            if (_confirmError != null)
              const SizedBox(height: HivorrSpacing.sm),
            HivorrButton(
              label: 'Confirm booking',
              onPressed: _confirming ? null : () => unawaited(_confirm()),
              variant: HivorrButtonVariant.primary,
              isExpanded: true,
              isLoading: _confirming,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.loading,
    required this.error,
    required this.day,
    required this.picked,
    required this.slotTaken,
    required this.onRetrySlots,
    required this.onPick,
    required this.onManual,
    required this.onPickManualTime,
    required this.manualStart,
    required this.manualEnd,
    required this.useManual,
  });

  final bool loading;
  final ApiException? error;
  final DateTime day;
  final DateTime? picked;
  final bool slotTaken;
  final VoidCallback onRetrySlots;
  final ValueChanged<DateTime> onPick;
  final void Function(TimeOfDay start, TimeOfDay end) onManual;
  final Future<void> Function(bool isStart) onPickManualTime;
  final TimeOfDay manualStart;
  final TimeOfDay manualEnd;
  final bool useManual;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const HivorrLoadingState(message: 'Loading slots…');
    }
    if (error != null) {
      return HivorrErrorState(
        message: 'Could not load slots',
        detail: error!.message,
        onRetry: onRetrySlots,
      );
    }
    return _SlotGrid(
      day: day,
      picked: picked,
      slotTaken: slotTaken,
      onPick: onPick,
      manualStart: manualStart,
      manualEnd: manualEnd,
      useManual: useManual,
      onPickManualTime: onPickManualTime,
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.day,
    required this.picked,
    required this.slotTaken,
    required this.onPick,
    required this.manualStart,
    required this.manualEnd,
    required this.useManual,
    required this.onPickManualTime,
  });

  final DateTime day;
  final DateTime? picked;
  final bool slotTaken;
  final ValueChanged<DateTime> onPick;
  final TimeOfDay manualStart;
  final TimeOfDay manualEnd;
  final bool useManual;
  final Future<void> Function(bool isStart) onPickManualTime;

  String _label(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final List<AvailabilitySlot> slots = context
        .watch<SchedulingProvider>()
        .slots;
    final List<AvailabilitySlot> daySlots = slots
        .where(
          (AvailabilitySlot s) =>
              s.isActive && s.weekday == day.weekday % 7,
        )
        .toList(growable: false);
    final List<DateTime> windows = SlotPickerSheet.windowsForDay(
      day,
      daySlots,
    );
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Available times · ${HivorrFormatters.date(day)}',
            style: context.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          if (windows.isEmpty)
            const HivorrEmptyState(
              title: 'No availability',
              subtitle:
                  'The professional has no slots on this day. Pick another date or set a custom time.',
            )
          else
            Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              children: <Widget>[
                for (final DateTime window in windows)
                  HivorrChip(
                    label: HivorrFormatters.time(window),
                    isSelected:
                        picked != null &&
                        picked!.isAtSameMomentAs(window),
                    onSelected: (_) => onPick(window),
                  ),
              ],
            ),
          const SizedBox(height: HivorrSpacing.md),
          Text(
            'Or set a custom time',
            style: context.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: HivorrButton(
                  label: _label(manualStart),
                  onPressed: () => unawaited(onPickManualTime(true)),
                  variant: useManual
                      ? HivorrButtonVariant.primary
                      : HivorrButtonVariant.outline,
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: HivorrButton(
                  label: _label(manualEnd),
                  onPressed: () => unawaited(onPickManualTime(false)),
                  variant: useManual
                      ? HivorrButtonVariant.primary
                      : HivorrButtonVariant.outline,
                  isExpanded: true,
                ),
              ),
            ],
          ),
          if (slotTaken) ...[
            const SizedBox(height: 8),
            Text(
              'That time was just taken. Pick another time.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
