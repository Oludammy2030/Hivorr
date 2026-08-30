import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';

/// Debounced taxonomy search input with a clear affordance.
///
/// Propagates [onQueryChanged] only after the debounce window elapses (default
/// 250ms) to avoid per-keystroke recompute in the registry browser. The clear
/// button resets the query immediately. Built from [AppTheme] tokens and the
/// shared [HivorrTextField] primitive (AGENT.md Rule 5).
class TaxonomySearchField extends StatefulWidget {
  const TaxonomySearchField({
    super.key,
    this.controller,
    this.onQueryChanged,
    this.debounce = const Duration(milliseconds: 250),
    this.hint = 'Search industries or professions',
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onQueryChanged;
  final Duration debounce;
  final String hint;

  @override
  State<TaxonomySearchField> createState() => _TaxonomySearchFieldState();
}

class _TaxonomySearchFieldState extends State<TaxonomySearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onControllerChanged);
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.text != _text) {
      setState(() => _text = _controller.text);
    }
  }

  void _onChanged(String value) {
    setState(() => _text = value);
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () {
      widget.onQueryChanged?.call(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _text = '');
    widget.onQueryChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return HivorrTextField(
      controller: _controller,
      hint: widget.hint,
      onChanged: _onChanged,
      suffix: _text.isEmpty
          ? null
          : IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.close),
              tooltip: 'Clear search',
            ),
    );
  }
}
