import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Themed text input built from [AppTheme] tokens (AGENT.md Rule 5).
///
/// Supports label, hint, inline error, helper text, prefix/suffix, password
/// masking, multi-line input, and a character counter. All borders resolve to
/// [ColorScheme] tokens; text inherits [TextTheme].
class HivorrTextField extends StatelessWidget {
  const HivorrTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.hideCounter = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.fillColor,
    this.enabled = true,
  });

  final TextEditingController? controller;

  /// Focus traversal hook (e.g. `FocusScope.nextFocus` chains in forms and
  /// chat composers). Null lets Flutter manage focus automatically.
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;

  /// Hides the built-in character counter while still enforcing [maxLength]
  /// (chat composers, search fields). Defaults to showing the counter.
  final bool hideCounter;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  /// Fill override (e.g. tinted search fields). Defaults to
  /// [ColorScheme.surface].
  final Color? fillColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final InputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ext.radiusSm),
      borderSide: BorderSide(color: colors.outline),
    );
    final InputBorder focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ext.radiusSm),
      borderSide: BorderSide(color: colors.primary, width: 2),
    );
    final InputBorder errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ext.radiusSm),
      borderSide: BorderSide(color: colors.error),
    );
    return Semantics(
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        enabled: enabled,
        style: context.textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          errorText: hasError ? errorText : null,
          prefixIcon: prefix,
          suffixIcon: suffix,
          filled: true,
          fillColor: fillColor ?? colors.surface,
          counterText: hideCounter ? '' : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: HivorrSpacing.sm,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: focusedBorder,
          errorBorder: errorBorder,
          focusedErrorBorder: errorBorder.copyWith(
            borderSide: BorderSide(color: colors.error, width: 2),
          ),
        ),
      ),
    );
  }
}
