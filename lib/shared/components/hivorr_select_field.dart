import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/shared/components/hivorr_bottom_sheet.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';

/// A single option in a [HivorrSelectField] or [HivorrSelectField.showOptions].
class SelectOption<T> {
  const SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  /// The value reported on selection.
  final T value;

  /// Primary display text (matched by the option search).
  final String label;

  /// Optional secondary text (also matched by the option search).
  final String? subtitle;
}

/// Result of [HivorrSelectField.showOptions].
///
/// A `null` future value means dismissal (backdrop, ESC/back, swipe) — the
/// caller must leave its state untouched. A non-null [SelectResult] means an
/// explicit choice: [value] is the picked option, or `null` for the reset
/// row ([HivorrSelectField.clearLabel]).
class SelectResult<T> {
  const SelectResult(this.value);

  /// Picked value, or `null` for the explicit reset row.
  final T? value;
}

/// Compact searchable select built from [AppTheme] tokens.
///
/// The trigger reuses the `HivorrTextField` border/fill/radius/focus tokens
/// (border `outline` idle / `primary` 2px focused / `error`, `surface` fill,
/// `radiusSm`, 48dp floor) with a trailing chevron. Tapping opens an
/// independent selection surface — never an inline list — so the host card
/// keeps a constant height no matter how many options exist:
///
/// * phones: keyboard-aware [HivorrBottomSheet] option sheet;
/// * tablet/desktop: dimmed-background [HivorrDialog] option card.
///
/// The option list scrolls independently and becomes searchable once the
/// option count exceeds [searchThreshold] (small datasets stay a plain
/// select; large datasets stay searchable with no redesign).
class HivorrSelectField<T> extends StatelessWidget {
  const HivorrSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.hint,
    this.clearLabel,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.loading = false,
    this.searchThreshold = _defaultSearchThreshold,
    this.searchHint = 'Search…',
    this.optionsTitle,
  });

  /// Caption rendered above the trigger (e.g. `Industry`).
  final String label;

  /// All available options (data-driven; never hardcoded at call sites).
  final List<SelectOption<T>> options;

  /// Currently selected value (`null` = nothing selected).
  final T? selected;

  /// Called with the picked value, or `null` for the clear row / dismissal
  /// semantics owned by the caller.
  final ValueChanged<T?> onSelected;

  /// Placeholder shown when nothing is selected (e.g. `Select industry`).
  final String? hint;

  /// When non-null, the option surface starts with a reset row carrying this
  /// label (e.g. `All industries`); tapping it reports `null`.
  final String? clearLabel;

  /// Helper line under the trigger (e.g. `Select industry first`).
  final String? helperText;

  /// Error line under the trigger.
  final String? errorText;

  /// When `false`, the trigger is visibly disabled and does not open.
  final bool enabled;

  /// When `true`, the trigger shows a loading placeholder and does not open.
  final bool loading;

  /// Option lists longer than this show a search field (intelligent
  /// threshold: small lists stay simple, large lists stay searchable).
  final int searchThreshold;

  /// Hint for the option-list search field.
  final String searchHint;

  /// Title of the option surface. Defaults to [label].
  final String? optionsTitle;

  /// Default search threshold (lists longer than this become searchable).
  static const int _defaultSearchThreshold = 8;

  /// Display label for the current selection, if any.
  String? selectedLabel() {
    final T? value = selected;
    if (value == null) return null;
    for (final SelectOption<T> option in options) {
      if (option.value == value) return option.label;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled || loading) return;
    final SelectResult<T>? result =
        await HivorrSelectField.showOptions<T>(
      context: context,
      title: optionsTitle ?? label,
      options: options,
      selected: selected,
      clearLabel: clearLabel,
      searchThreshold: searchThreshold,
      searchHint: searchHint,
      loading: loading,
    );
    // Dismissal (`null`) leaves state untouched; an explicit result either
    // picks a value or resets via the clear row (`value == null`).
    if (result != null) onSelected(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final String? display = loading ? 'Loading…' : selectedLabel();
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: display ?? hint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: enabled
                  ? context.colorScheme.onSurfaceVariant
                  : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          _Trigger(
            display: display,
            hint: hint,
            errorText: errorText,
            enabled: enabled,
            onTap: () => _open(context),
          ),
          if (errorText != null && errorText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HivorrSpacing.xs),
              child: Text(
                errorText!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            )
          else if (helperText != null)
            Padding(
              padding: const EdgeInsets.only(top: HivorrSpacing.xs),
              child: Text(
                helperText!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Presents an independent option-selection surface.
  ///
  /// Returns `null` on dismissal (backdrop, ESC/back, swipe) — the caller
  /// must leave its state untouched. Returns a [SelectResult] for an
  /// explicit choice: the picked value, or `null` ([SelectResult.value])
  /// for the reset row when [clearLabel] is set.
  static Future<SelectResult<T>?> showOptions<T>({
    required BuildContext context,
    required String title,
    required List<SelectOption<T>> options,
    required T? selected,
    String? clearLabel,
    bool loading = false,
    int searchThreshold = _defaultSearchThreshold,
    String searchHint = 'Search…',
    String emptyLabel = 'No matches',
  }) {
    final bool searchable = options.length > searchThreshold;
    Widget content({required double listHeight}) => _OptionList<T>(
      options: options,
      selected: selected,
      clearLabel: clearLabel,
      loading: loading,
      searchable: searchable,
      searchHint: searchHint,
      emptyLabel: emptyLabel,
      listHeight: listHeight,
    );
    if (context.breakpoint != Breakpoint.mobile) {
      return showDialog<SelectResult<T>>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: HivorrDialog(
            title: title,
            content: SizedBox(
              width: 420,
              child: content(listHeight: 384),
            ),
          ),
        ),
      );
    }
    return HivorrBottomSheet.show<SelectResult<T>>(
      context: context,
      title: title,
      child: content(listHeight: 320),
    );
  }
}

/// Trigger box reusing the `HivorrTextField` border/fill/radius/focus tokens
/// plus the 48dp floor (VISUAL-IDENTITY.md §526).
class _Trigger extends StatefulWidget {
  const _Trigger({
    required this.display,
    required this.hint,
    required this.errorText,
    required this.enabled,
    required this.onTap,
  });

  final String? display;
  final String? hint;
  final String? errorText;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;
    final Color border = hasError
        ? colors.error
        : _focused
            ? colors.primary
            : colors.outline;
    final String? display = widget.display;
    return Focus(
      focusNode: _focusNode,
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        borderRadius: BorderRadius.circular(ext.radiusSm),
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.6,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.md,
              vertical: HivorrSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(ext.radiusSm),
              border: Border.all(
                color: border,
                width: _focused || hasError ? 2 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    display ?? widget.hint ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: display != null
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable, independently-sized option list with optional search.
class _OptionList<T> extends StatefulWidget {
  const _OptionList({
    required this.options,
    required this.selected,
    required this.clearLabel,
    required this.loading,
    required this.searchable,
    required this.searchHint,
    required this.emptyLabel,
    required this.listHeight,
  });

  final List<SelectOption<T>> options;
  final T? selected;
  final String? clearLabel;
  final bool loading;
  final bool searchable;
  final String searchHint;
  final String emptyLabel;
  final double listHeight;

  @override
  State<_OptionList<T>> createState() => _OptionListState<T>();
}

class _OptionListState<T> extends State<_OptionList<T>> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  List<SelectOption<T>> get _visible {
    if (_query.isEmpty) return widget.options;
    return widget.options.where((SelectOption<T> option) {
      final String haystack =
          '${option.label} ${option.subtitle ?? ''}'.toLowerCase();
      return haystack.contains(_query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<SelectOption<T>> visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.searchable) ...<Widget>[
          HivorrTextField(
            controller: _searchController,
            hint: widget.searchHint,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            suffix: _searchController.text.isEmpty && _query.isEmpty
                ? const Icon(Icons.search)
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close),
                  ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
        ],
        if (widget.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
            child: Text(
              'Loading…',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...<Widget>[
          if (widget.clearLabel != null && _query.isEmpty)
            _OptionRow<T>(
              label: widget.clearLabel!,
              isSelected: widget.selected == null,
              onTap: () =>
                  Navigator.of(context).pop(SelectResult<T>(null)),
            ),
          SizedBox(
            height: widget.listHeight,
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      widget.emptyLabel,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: false,
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: HivorrSpacing.xs,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final SelectOption<T> option = visible[index];
                      return _OptionRow<T>(
                        label: option.label,
                        subtitle: option.subtitle,
                        isSelected: option.value == widget.selected,
                        onTap: () => Navigator.of(context)
                            .pop(SelectResult<T>(option.value)),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

/// Single selectable row: 48dp floor, token text, check on selection.
class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return InkWell(
      key: ValueKey<String>('hivorr-select-option-$label'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(ext.radiusSm),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.smMd,
          vertical: HivorrSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer : null,
          borderRadius: BorderRadius.circular(ext.radiusSm),
          border: Border.all(
            color: isSelected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colors.primary, size: 20)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: colors.outline,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
