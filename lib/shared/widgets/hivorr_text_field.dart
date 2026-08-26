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
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
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
        obscureText: obscureText,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        onChanged: onChanged,
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
          fillColor: colors.surface,
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
