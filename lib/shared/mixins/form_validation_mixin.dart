import 'package:flutter/material.dart';

/// Form validation orchestration for screens that own a [Form].
///
/// Provides a [formKey] for [Form] widgets and a [validate] / [reset] shortcut
/// so callers do not reconstruct the key or re-implement the boilerplate.
mixin FormValidationMixin {
  /// The [GlobalKey] that binds this mixin to a [Form] widget.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  /// Validates the bound form, returning `true` when all fields pass.
  ///
  /// Returns `false` when there is no form mounted (defensive against a null
  /// [FormState]) so callers never dereference a null state.
  bool validate() => formKey.currentState?.validate() ?? false;

  /// Resets the bound form, clearing all field values.
  void reset() => formKey.currentState?.reset();

  /// Per-field error messages keyed by field name, as reported by the last
  /// validation pass. Subclasses override to expose their specific errors.
  Map<String, String?> get fieldErrors => <String, String?>{};
}
