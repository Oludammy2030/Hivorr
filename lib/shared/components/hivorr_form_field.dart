import 'package:flutter/material.dart';

import 'package:hivorr/shared/widgets/hivorr_text_field.dart';

/// Form-integrated text field built from [HivorrTextField] plus [FormField]
/// validation wiring.
///
/// Inline errors are surfaced through [FormFieldState.errorText] (driven by
/// [autovalidateMode], defaulting to validation on user interaction and on
/// explicit [Form.validate]).
class HivorrFormField extends FormField<String> {
  HivorrFormField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    super.enabled = true,
    super.validator,
    super.autovalidateMode = AutovalidateMode.onUserInteraction,
    super.onSaved,
    String? initialValue,
  }) : super(
          initialValue: initialValue ?? controller?.text,
          builder: (FormFieldState<String> state) => _HivorrFormFieldView(
            state: state,
            controller: controller,
            label: label,
            hint: hint,
            helperText: helperText,
            prefix: prefix,
            suffix: suffix,
            obscureText: obscureText,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            onChanged: onChanged,
            enabled: enabled,
          ),
        );

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
}

class _HivorrFormFieldView extends StatelessWidget {
  const _HivorrFormFieldView({
    required this.state,
    this.controller,
    this.label,
    this.hint,
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

  final FormFieldState<String> state;
  final TextEditingController? controller;
  final String? label;
  final String? hint;
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
    return HivorrTextField(
      controller: controller,
      label: label,
      hint: hint,
      errorText: state.errorText,
      helperText: helperText,
      prefix: prefix,
      suffix: suffix,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: (String value) {
        state.didChange(value);
        onChanged?.call(value);
      },
    );
  }
}
