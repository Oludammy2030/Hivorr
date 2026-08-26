import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/extensions/string_extensions.dart';

/// Circular avatar with an image or an initials fallback.
///
/// When [image] is `null`, the avatar shows up to two uppercase [initials]
/// derived from [name], or a person icon when [name] is empty.
class HivorrAvatar extends StatelessWidget {
  const HivorrAvatar({
    super.key,
    this.image,
    this.name = '',
    this.size = 48,
    this.backgroundColor,
  });

  /// Optional image provider. When `null`, initials fallback is used.
  final ImageProvider? image;

  /// Name used to derive initials; also used as the semantics label.
  final String name;

  /// Rendered diameter in logical pixels.
  final double size;

  /// Optional override for the background fill.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? context.colorScheme.primaryContainer;
    final Color fg = context.colorScheme.onPrimaryContainer;
    return Semantics(
      label: name.isNotEmpty ? name : 'Avatar',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: image != null
            ? Image(
                image: image!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : Center(
                child: name.initials.isNotEmpty
                    ? Text(
                        name.initials,
                        style: context.textTheme.titleMedium?.copyWith(color: fg),
                      )
                    : Icon(Icons.person, color: fg, size: size * 0.5),
              ),
      ),
    );
  }
}
