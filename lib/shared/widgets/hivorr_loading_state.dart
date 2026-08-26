import 'package:flutter/material.dart';

import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Full-area loading placeholder built around the branded [HivorrLoader]
/// (not a generic spinner) with an optional message.
class HivorrLoadingState extends StatelessWidget {
  const HivorrLoadingState({
    super.key,
    this.message,
  });

  /// Optional caption shown beneath the loader.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const HivorrLoader(size: 64),
          if (message != null && message!.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            Text(
              message!,
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: context.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
