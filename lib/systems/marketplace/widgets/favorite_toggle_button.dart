import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';

/// Favorite heart for public discovery rows (EP-03-09).
///
/// Thin wrapper over the existing `service_favorite_toggle` RPC (via
/// [ServiceListingService.toggleFavorite]) — read-through for detail preview
/// only. Holds optimistic local state and reconciles on failure. All copy is
/// guidance-oriented: self-favorite (`PLT005`) and signed-out states explain
/// the next step instead of failing silently.
///
/// When no [ServiceListingService] is in the tree (e.g. isolated widget
/// tests), the button renders disabled with an explanatory tooltip.
class FavoriteToggleButton extends StatefulWidget {
  const FavoriteToggleButton({
    super.key,
    required this.listingId,
    this.initialFavorited = false,
  });

  /// The `service_listings.id` to toggle.
  final String listingId;

  /// Favorite state from the detail preview read-through.
  final bool initialFavorited;

  @override
  State<FavoriteToggleButton> createState() => _FavoriteToggleButtonState();
}

class _FavoriteToggleButtonState extends State<FavoriteToggleButton> {
  late bool _favorited = widget.initialFavorited;
  bool _busy = false;

  @override
  void didUpdateWidget(FavoriteToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFavorited != widget.initialFavorited && !_busy) {
      _favorited = widget.initialFavorited;
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    ServiceListingService? service;
    try {
      service = context.read<ServiceListingService>();
    } on Object {
      service = null;
    }
    if (service == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Saving favorites is unavailable right now.',
          variant: HivorrSnackbarVariant.warning,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final bool favorited = await service.toggleFavorite(widget.listingId);
      if (!mounted) return;
      setState(() => _favorited = favorited);
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: favorited
              ? 'Saved to your favorites.'
              : 'Removed from your favorites.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: _friendlyMessage(e),
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _friendlyMessage(ApiException e) {
    if (e.kind == ApiExceptionKind.auth || e.code == 'PLT001') {
      return 'Sign in to save favorites.';
    }
    if (e.code == 'PLT005') {
      return e.message.isNotEmpty
          ? e.message
          : 'This listing cannot be favorited.';
    }
    if (e.code == 'PLT004') {
      return 'This listing is no longer available.';
    }
    return e.message.isNotEmpty ? e.message : 'Could not save favorite.';
  }

  @override
  Widget build(BuildContext context) {
    final bool on = _favorited;
    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Remove from favorites' : 'Save to favorites',
      child: IconButton(
        tooltip: on ? 'Remove from favorites' : 'Save to favorites',
        onPressed: _busy ? null : _toggle,
        icon: _busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colorScheme.primary,
                ),
              )
            : Icon(
                on ? Icons.favorite : Icons.favorite_border,
                color: on
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}
