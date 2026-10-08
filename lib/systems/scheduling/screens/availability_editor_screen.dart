import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/scheduling_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/components/hivorr_select_field.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/mixins/form_validation_mixin.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';
import 'package:hivorr/workspace/profession_registry/widgets/profession_picker.dart';
import 'package:provider/provider.dart';

/// Availability template editor (EP-03-14 §8 D7).
///
/// `GET /availability?professionId=`. Profession context (via
/// `profession_picker` + `taxonomy_engine` when a `TaxonomyProvider` is
/// present, otherwise a profession-id field) + Mon–Sun [HivorrChip] rows each
/// with start/end time pickers + duration stepper + timezone caption
/// (default `Africa/Lagos`) + `is_active` switch + draft-validated
/// `Save availability`. Writes only via `availability_upsert`; re-save is
/// idempotent per `(entity, profession, weekday, start)`
/// (`ON CONFLICT DO UPDATE`). All authoritative checks stay server-side
/// (`AGENT.md` Rule 4). Tokens only (Rule 5).
class AvailabilityEditorScreen extends StatefulWidget {
  const AvailabilityEditorScreen({super.key, this.professionId});

  /// Pre-selected `professions.id`, when launched with a profession context.
  final String? professionId;

  @override
  State<AvailabilityEditorScreen> createState() =>
      _AvailabilityEditorScreenState();
}

class _DayDraft {
  _DayDraft({TimeOfDay? start, TimeOfDay? end})
    : start = start ?? const TimeOfDay(hour: 9, minute: 0),
      end = end ?? const TimeOfDay(hour: 12, minute: 0);

  bool enabled = false;
  TimeOfDay start;
  TimeOfDay end;
  int durationMin = 60;
  bool isActive = true;
}

class _AvailabilityEditorScreenState extends State<AvailabilityEditorScreen>
    with FormValidationMixin {
  final TextEditingController _professionController =
      TextEditingController();
  final TextEditingController _timezoneController = TextEditingController(
    text: SchedulingService.defaultTimezone,
  );
  final Map<int, _DayDraft> _days = <int, _DayDraft>{
    for (int weekday = 0; weekday <= 6; weekday++)
      weekday: _DayDraft(),
  };
  bool _loading = true;
  ApiException? _loadError;
  bool _saving = false;
  String? _formError;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (widget.professionId != null) {
        _professionController.text = widget.professionId!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _professionController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final String? professionId =
          _professionController.text.trim().isEmpty
          ? null
          : _professionController.text.trim();
      // Best-effort taxonomy hydration for the profession browser; the
      // editor stays fully usable without a TaxonomyProvider in the tree.
      // Providers are captured before the first await (never `context`
      // across async gaps).
      final SchedulingProvider scheduling = context.read<SchedulingProvider>();
      final TaxonomyProvider? taxonomy = _taxonomy;
      await taxonomy?.loadIndustries();
      await scheduling.loadSlots(professionId: professionId);
      if (!mounted) return;
      final List<AvailabilitySlot> slots = scheduling.slots;
      for (final AvailabilitySlot slot in slots) {
        final _DayDraft? draft = _days[slot.weekday];
        if (draft == null) continue;
        draft.enabled = true;
        draft.start = _parseTime(slot.startTime) ?? draft.start;
        draft.end = _parseTime(slot.endTime) ?? draft.end;
        draft.durationMin = slot.slotDurationMin;
        draft.isActive = slot.isActive;
        if (_professionController.text.trim().isEmpty) {
          _professionController.text = slot.professionId;
        }
      }
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.kind == ApiExceptionKind.notFound ? null : e;
      });
    }
  }

  /// The taxonomy provider when one is available in the tree (`null`
  /// otherwise — the profession-id field covers that case).
  TaxonomyProvider? get _taxonomy {
    try {
      return Provider.of<TaxonomyProvider>(context, listen: false);
    } on Object {
      return null;
    }
  }

  TimeOfDay? _parseTime(String time) {
    final List<String> parts = time.split(':');
    if (parts.length < 2) return null;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(int weekday, bool isStart) async {
    final _DayDraft draft = _days[weekday]!;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? draft.start : draft.end,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          draft.start = picked;
        } else {
          draft.end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final String professionId = _professionController.text.trim();
    final String timezone = _timezoneController.text.trim().isEmpty
        ? SchedulingService.defaultTimezone
        : _timezoneController.text.trim();
    if (professionId.isEmpty) {
      setState(() => _formError = 'Profession is required.');
      return;
    }
    if (!SchedulingService.validateTimezone(timezone)) {
      setState(() => _formError = 'Invalid timezone.');
      return;
    }
    final List<int> enabled = _days.entries
        .where((MapEntry<int, _DayDraft> e) => e.value.enabled)
        .map((MapEntry<int, _DayDraft> e) => e.key)
        .toList(growable: false);
    if (enabled.isEmpty) {
      setState(() => _formError = 'Enable at least one weekday.');
      return;
    }
    for (final int weekday in enabled) {
      final _DayDraft draft = _days[weekday]!;
      if (!SchedulingService.validateTimeRange(
        _format(draft.start),
        _format(draft.end),
      )) {
        setState(
          () => _formError =
              '${SchedulingService.weekdayLabel(weekday)}: start must be before end.',
        );
        return;
      }
      if (!SchedulingService.validateDuration(draft.durationMin)) {
        setState(
          () => _formError =
              '${SchedulingService.weekdayLabel(weekday)}: duration must be 15–480 minutes.',
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final SchedulingProvider provider = context.read<SchedulingProvider>();
      for (final int weekday in enabled) {
        final _DayDraft draft = _days[weekday]!;
        await provider.upsertSlot(
          professionId: professionId,
          weekday: weekday,
          startTime: _format(draft.start),
          endTime: _format(draft.end),
          slotDurationMin: draft.durationMin,
          timezone: timezone,
          isActive: draft.isActive,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Availability saved.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: HivorrContentPane(
        child: _loading
            ? const HivorrLoadingState(message: 'Loading availability…')
            : _loadError != null
            ? HivorrErrorState(
                message: 'Could not load availability',
                detail: _loadError!.message,
                onRetry: () => unawaited(_load()),
              )
            : Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: HivorrSpacing.md,
                  ),
                  children: <Widget>[
                    _ProfessionSection(
                      professionId: _professionController.text.trim(),
                      onProfessionSelected: (String id) {
                        setState(() => _professionController.text = id);
                        unawaited(_load());
                      },
                    ),
                    HivorrTextField(
                      controller: _professionController,
                      label: 'Profession ID',
                      hint: 'Select a profession for these hours',
                      onChanged: (_) => unawaited(_load()),
                    ),
                    const SizedBox(height: HivorrSpacing.md),
                    for (int weekday = 0; weekday <= 6; weekday++)
                      _DayRow(
                        weekday: weekday,
                        draft: _days[weekday]!,
                        onChanged: () => setState(() {}),
                        onPickTime: (bool isStart) =>
                            _pickTime(weekday, isStart),
                      ),
                    const SizedBox(height: HivorrSpacing.md),
                    HivorrTextField(
                      controller: _timezoneController,
                      label: 'Timezone',
                      hint: SchedulingService.defaultTimezone,
                    ),
                    const SizedBox(height: HivorrSpacing.md),
                    if (_formError != null)
                      HivorrErrorState(
                        message: _formError!,
                        onRetry: () =>
                            setState(() => _formError = null),
                      ),
                    if (_formError != null)
                      const SizedBox(height: HivorrSpacing.sm),
                    HivorrButton(
                      label: 'Save availability',
                      onPressed: _saving ? null : () => unawaited(_save()),
                      variant: HivorrButtonVariant.primary,
                      isExpanded: true,
                      isLoading: _saving,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Profession browser for the availability editor (EP-03-14 §8 D7).
///
/// Industry dropdown (via `taxonomy_engine`) + [ProfessionPicker] list bound
/// to the [TaxonomyProvider]. Renders nothing when no taxonomy provider is in
/// the tree — the profession-id field below covers that case, so the editor
/// stays fully usable in isolation and in tests.
class _ProfessionSection extends StatelessWidget {
  const _ProfessionSection({
    required this.professionId,
    required this.onProfessionSelected,
  });

  /// Currently selected `professions.id` (`''` when none).
  final String professionId;

  /// Called with the picked `professions.id`.
  final ValueChanged<String> onProfessionSelected;

  @override
  Widget build(BuildContext context) {
    final TaxonomyProvider? taxonomy = _optionalTaxonomy(context);
    if (taxonomy == null) return const SizedBox.shrink();
    final List<Industry> industries = taxonomy.industries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (industries.isNotEmpty)
          HivorrSelectField<String>(
            label: 'Industry',
            options: <SelectOption<String>>[
              for (final Industry industry in industries)
                SelectOption<String>(
                  value: industry.id,
                  label: industry.name,
                  subtitle: industry.description,
                ),
            ],
            selected: taxonomy.selectedIndustry?.id,
            onSelected: (String? id) {
              if (id == null) return;
              taxonomy.selectIndustry(id);
              unawaited(taxonomy.loadProfessions(id));
            },
          ),
        if (industries.isNotEmpty)
          const SizedBox(height: HivorrSpacing.sm),
        ProfessionPicker(
          professions: taxonomy.professionsForSelectedIndustry,
          selectedId: professionId.isEmpty ? null : professionId,
          onSelected: (Profession profession) =>
              onProfessionSelected(profession.id),
        ),
        const SizedBox(height: HivorrSpacing.md),
      ],
    );
  }

  TaxonomyProvider? _optionalTaxonomy(BuildContext context) {
    try {
      return Provider.of<TaxonomyProvider>(context);
    } on Object {
      return null;
    }
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekday,
    required this.draft,
    required this.onChanged,
    required this.onPickTime,
  });

  final int weekday;
  final _DayDraft draft;
  final VoidCallback onChanged;
  final ValueChanged<bool> onPickTime;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              HivorrChip(
                label: SchedulingService.weekdayLabel(weekday),
                isSelected: draft.enabled,
                onSelected: (_) {
                  draft.enabled = !draft.enabled;
                  onChanged();
                },
              ),
              const Spacer(),
              Switch(
                value: draft.isActive,
                onChanged: draft.enabled
                    ? (bool value) {
                        draft.isActive = value;
                        onChanged();
                      }
                    : null,
              ),
            ],
          ),
          if (draft.enabled) ...[
            const SizedBox(height: HivorrSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: HivorrButton(
                    label:
                        '${draft.start.hour.toString().padLeft(2, '0')}:${draft.start.minute.toString().padLeft(2, '0')}',
                    onPressed: () => onPickTime(true),
                    variant: HivorrButtonVariant.outline,
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: HivorrButton(
                    label:
                        '${draft.end.hour.toString().padLeft(2, '0')}:${draft.end.minute.toString().padLeft(2, '0')}',
                    onPressed: () => onPickTime(false),
                    variant: HivorrButtonVariant.outline,
                    isExpanded: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HivorrSpacing.sm),
            HivorrSelectField<int>(
              label: 'Slot length',
              options: <SelectOption<int>>[
                for (final int minutes
                    in SchedulingService.durationPresets)
                  SelectOption<int>(
                    value: minutes,
                    label: '$minutes min',
                  ),
              ],
              selected: draft.durationMin,
              onSelected: (int? value) {
                if (value == null) return;
                draft.durationMin = value;
                onChanged();
              },
            ),
          ],
        ],
      ),
    );
  }
}
