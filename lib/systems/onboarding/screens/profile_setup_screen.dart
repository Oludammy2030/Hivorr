import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/onboarding/models/picked_avatar.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_avatar_picker.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:provider/provider.dart';

/// Max lengths mirror the `entity_profile_update` RPC parameter sizes
/// (`supabase/migrations/20260821090004_entity_model_rpcs.sql:40,51,59`).
///
/// The combined legal name (first + middle + last) must stay within
/// [legalName] (255 chars). Individual part limits are generous soft caps.
// ignore: avoid_classes_with_only_static_members
abstract final class ProfileFieldLimits {
  const ProfileFieldLimits._();

  static const int firstName = 120;
  static const int middleName = 120;
  static const int lastName = 120;
  static const int legalName = 255;
  static const int displayName = 255;
  static const int bio = 5000;
}

/// Step 1 — Basic Information (EP-02-18 FV-29).
///
/// The account's basics: first name (required), middle name (optional), last
/// name (required), display name (required), verified email (read-only from
/// the auth session — never re-collected or written to business tables),
/// optional phone (client-side format check only; not persisted), an optional
/// bio, and an [OnboardingAvatarPicker]. Continue is disabled until the names
/// are valid — fail-fast before the RPC, no `PLT003` round-trip. Submitting
/// runs `completeProfile` (avatar upload → RPC → avatar_path persist) then
/// advances to capability selection.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.active,
    required this.controller,
    this.pickAvatar,
  });

  /// Whether this is the active shell step (configures the CTA bar).
  final bool active;

  /// Shell-owned CTA controller.
  final OnboardingStepController controller;

  /// Injected image picker; when `null` a stub is used and avatar selection
  /// stays disabled.
  final PickAvatarCallback? pickAvatar;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _middleName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  PickedAvatar? _avatar;
  int _sent = 0;
  int _total = 0;
  bool _uploading = false;
  String? _phoneError;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _email.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  String get _combinedLegalName {
    final String first = _firstName.text.trim();
    final String middle = _middleName.text.trim();
    final String last = _lastName.text.trim();
    if (middle.isEmpty) return '$first $last';
    return '$first $middle $last';
  }

  bool get _namesValid {
    final String first = _firstName.text.trim();
    final String last = _lastName.text.trim();
    final String display = _displayName.text.trim();
    final String combined = _combinedLegalName;
    return first.isNotEmpty &&
        last.isNotEmpty &&
        display.isNotEmpty &&
        combined.length <= ProfileFieldLimits.legalName;
  }

  /// Phone is optional; when filled it must be a plausible number (7–15
  /// digits after stripping formatting). Client-side only — not persisted.
  bool get _phoneValid {
    final String digits = _phone.text.trim().replaceAll(RegExp(r'\D'), '');
    return _phone.text.trim().isEmpty ||
        (digits.length >= 7 && digits.length <= 15);
  }

  void _onPhoneChanged() {
    final String? error = _phoneValid
        ? null
        : 'Enter a valid phone number or leave it blank.';
    setState(() => _phoneError = error);
  }

  /// The entity's verified sign-in email, when the auth provider is present.
  /// Resolved defensively so harnesses without [AuthProvider] stay readable.
  String? get _accountEmail {
    try {
      return context.read<AuthProvider>().currentSession?.email;
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final ColorScheme colors = context.colorScheme;
    final String? email = _accountEmail;
    if (email != null && _email.text != email) {
      _email.text = email;
    }

    widget.controller.configure(
      label: 'Save & continue',
      canPrimary: _namesValid && _phoneValid && !_uploading,
      loading: provider.isBusy,
      onPrimary: () => _submit(context),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              HivorrAvatar(
                image: _avatar == null ? null : MemoryImage(_avatar!.bytes),
                name: _displayName.text,
                size: 64,
              ),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(
                child: Text(
                  'This name appears publicly on your profile.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.lg),
          _buildNameFields(context),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _displayName,
            label: 'Display name',
            hint: 'How clients see you',
            maxLength: ProfileFieldLimits.displayName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _email,
            label: 'Email',
            enabled: false,
            helperText: 'Verified by your sign-in — not stored with your profile.',
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _phone,
            label: 'Phone (optional)',
            hint: '+1 555 000 1234',
            keyboardType: TextInputType.phone,
            errorText: _phoneError,
            onChanged: (_) => _onPhoneChanged(),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrTextField(
            controller: _bio,
            label: 'Bio',
            hint: 'A few words about your work (optional)',
            maxLength: ProfileFieldLimits.bio,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          Text('Profile avatar', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          OnboardingAvatarPicker(
            pickFile: _resolvePick(),
            value: _avatar,
            onChanged: (PickedAvatar? avatar) {
              setState(() {
                _avatar = avatar;
                _uploading = false;
              });
            },
            isUploading: _uploading,
            progress: _total == 0 ? null : _sent / _total,
            nameForFallback: _displayName.text,
          ),
          if (provider.lastError != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            Text(
              provider.lastError!.message,
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNameFields(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 480;
        final Widget firstName = HivorrTextField(
          controller: _firstName,
          label: 'First name',
          hint: 'Required',
          maxLength: ProfileFieldLimits.firstName,
          onChanged: (_) => setState(() {}),
        );
        final Widget middleName = HivorrTextField(
          controller: _middleName,
          label: 'Middle name',
          hint: 'Optional',
          maxLength: ProfileFieldLimits.middleName,
          onChanged: (_) => setState(() {}),
        );
        final Widget lastName = HivorrTextField(
          controller: _lastName,
          label: 'Last name',
          hint: 'Required',
          maxLength: ProfileFieldLimits.lastName,
          onChanged: (_) => setState(() {}),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: firstName),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(child: middleName),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(child: lastName),
            ],
          );
        }

        return Column(
          children: <Widget>[
            firstName,
            const SizedBox(height: HivorrSpacing.md),
            middleName,
            const SizedBox(height: HivorrSpacing.md),
            lastName,
          ],
        );
      },
    );
  }

  /// Resolves the avatar picker callback: the injected test seam first, else
  /// the app-wide [PlatformFilePicker] (with a silent stub when no provider is
  /// registered — test harnesses that omit the picker stay disabled).
  PickAvatarCallback _resolvePick() {
    if (widget.pickAvatar != null) {
      return widget.pickAvatar!;
    }
    try {
      final PlatformFilePicker platform = context.read<PlatformFilePicker>();
      return platform.pickAvatar;
    } on Object {
      return () async => null;
    }
  }

  Future<void> _submit(BuildContext context) async {
    final OnboardingProvider provider = context.read<OnboardingProvider>();
    final PickedAvatar? avatar = _avatar;
    setState(() {
      _uploading = avatar != null;
      _sent = 0;
      _total = avatar?.bytes.length ?? 0;
    });
    await provider.completeProfile(
      legalName: _combinedLegalName,
      displayName: _displayName.text.trim(),
      bio: _bio.text.trim().isEmpty ? null : _bio.text,
      avatarBytes: avatar?.bytes,
      avatarFileName: avatar?.fileName,
      avatarMimeType: avatar?.mimeType,
      onAvatarProgress: avatar == null
          ? null
          : (int sent, int total) {
              if (!mounted) {
                return;
              }
              setState(() {
                _sent = sent;
                _total = total;
              });
            },
    );
    if (!mounted) {
      return;
    }
    setState(() => _uploading = false);
    if (provider.submitState == SubmitState.success) {
      await provider.advance();
      if (!context.mounted) {
        return;
      }
      // Every entity advances to capability selection after Basic Information;
      // a hire choice later finishes the wizard, professional continues.
      context.goNamed(RouteNames.onboardingCapability);
    }
  }
}
