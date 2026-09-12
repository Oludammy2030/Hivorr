import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/onboarding/models/picked_avatar.dart';

/// Picker function contract: returns a platform-picked avatar, or `null` when
/// the user cancels.
typedef PickAvatarCallback = Future<PickedAvatar?> Function();

/// Profile-avatar picker (EP-02-18 FV-38).
///
/// Validates MIME/size against the `profile-avatars` bucket rules
/// (`StorageValidators.validateForBucket` — reject-before-upload) and shows a
/// [HivorrAvatar] preview using the picked bytes. The upload itself is the
/// first step of [OnboardingService.completeProfile]; [isUploading]/[progress]
/// render that upload's progress inside this picker.
class OnboardingAvatarPicker extends StatefulWidget {
  const OnboardingAvatarPicker({
    super.key,
    required this.pickFile,
    required this.onChanged,
    this.value,
    this.isUploading = false,
    this.progress,
    this.nameForFallback = '',
  });

  /// Platform file picker (mobile/Web `XFile.readAsBytes()`).
  final PickAvatarCallback pickFile;

  /// Reports a validated pick (`null` clears the avatar).
  final ValueChanged<PickedAvatar?> onChanged;

  /// Currently selected avatar (owned by the parent for CTA state).
  final PickedAvatar? value;

  /// Whether the avatar upload (first step of profile save) is in flight.
  final bool isUploading;

  /// Upload progress `0..1`, when [isUploading].
  final double? progress;

  /// Name used for the initials fallback while the avatar was never picked.
  final String nameForFallback;

  @override
  State<OnboardingAvatarPicker> createState() => _OnboardingAvatarPickerState();
}

class _OnboardingAvatarPickerState extends State<OnboardingAvatarPicker> {
  String? _fieldError;

  Future<void> _pick() async {
    final PickedAvatar? avatar = await widget.pickFile();
    if (avatar == null || !mounted) {
      return;
    }
    try {
      StorageValidators.validateForBucket(
        bucket: StorageBuckets.profileAvatars,
        mimeType: avatar.mimeType,
        byteLength: avatar.bytes.length,
      );
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fieldError = _friendlyError(e);
      });
      return;
    }
    setState(() {
      _fieldError = null;
    });
    widget.onChanged(avatar);
  }

  String _friendlyError(Object e) {
    final String lower = e.toString().toLowerCase();
    if (lower.contains('large')) {
      return 'This image is too large — please use a JPEG, PNG, or WebP under 5 MB.';
    }
    return 'This image type is not supported. Please use JPEG, PNG, or WebP.';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final PickedAvatar? value = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            HivorrAvatar(
              image: value == null
                  ? null
                  : MemoryImage(Uint8List.fromList(value.bytes)),
              name: value == null
                  ? widget.nameForFallback
                  : value.fileName,
              size: 72,
            ),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value == null
                        ? 'No avatar selected'
                        : value.fileName,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: HivorrSpacing.xs),
                  HivorrButton(
                    label: value == null ? 'Choose avatar' : 'Change avatar',
                    variant: value == null
                        ? HivorrButtonVariant.primary
                        : HivorrButtonVariant.outline,
                    size: HivorrButtonSize.small,
                    isLoading: widget.isUploading,
                    onPressed: widget.isUploading ? null : _pick,
                  ),
                  if (value != null) ...<Widget>[
                    const SizedBox(height: HivorrSpacing.xs),
                    TextButton(
                      onPressed:
                          widget.isUploading ? null : () => widget.onChanged(null),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Remove'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (widget.isUploading) ...<Widget>[
          const SizedBox(height: HivorrSpacing.sm),
          LinearProgressIndicator(
            value: widget.progress,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ],
        if (_fieldError != null) ...<Widget>[
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            _fieldError!,
            style: context.textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}