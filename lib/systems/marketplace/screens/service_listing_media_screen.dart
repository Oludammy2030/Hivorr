import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/listing_media_tile.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:provider/provider.dart';

/// Service listing media manager (EP-03-08 §8 D8).
///
/// `GET /services/mine/:id/media`. Grid of [ListingMediaTile] (thumbnail via
/// `getPublicUrl`, `LinearProgressIndicator`, retry), add FAB via
/// [PlatformFilePicker.pickListingMedia], cover = `sort_order 0`, delete via
/// [HivorrDialog] confirm. Upload-then-link ordering with orphan cleanup in
/// [ServiceListingService]. Tokens only (AGENT.md Rule 5).
class ServiceListingMediaScreen extends StatefulWidget {
  const ServiceListingMediaScreen({super.key, required this.listingId});

  /// The listing whose media is managed.
  final String listingId;

  @override
  State<ServiceListingMediaScreen> createState() =>
      _ServiceListingMediaScreenState();
}

class _PendingUpload {
  _PendingUpload({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  double progress = 0;
  String? error;
}

class _ServiceListingMediaScreenState
    extends State<ServiceListingMediaScreen> {
  bool _initialized = false;
  bool _busy = false;
  final List<_PendingUpload> _pending = <_PendingUpload>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            context
                .read<ServiceListingProvider>()
                .select(widget.listingId),
          );
        }
      });
    }
  }

  Future<void> _pickAndUpload() async {
    final PlatformFilePicker picker = context.read<PlatformFilePicker>();
    final PickedDocument? picked = await picker.pickListingMedia();
    if (picked == null || !mounted) return;
    final _PendingUpload pending = _PendingUpload(
      fileName: picked.fileName,
      bytes: picked.bytes,
      mimeType: picked.mimeType,
    );
    setState(() => _pending.add(pending));
    await _uploadPending(pending);
  }

  Future<void> _uploadPending(_PendingUpload pending) async {
    final ServiceListingProvider provider =
        context.read<ServiceListingProvider>();
    final ServiceListingService service =
        context.read<ServiceListingService>();
    setState(() {
      pending.error = null;
      pending.progress = 0;
      _busy = true;
    });
    try {
      final int sortOrder = (provider.selected?.media.length ?? 0) +
          _pending.indexOf(pending);
      await service.uploadMedia(
        listingId: widget.listingId,
        bytes: pending.bytes,
        mimeType: pending.mimeType,
        fileName: pending.fileName,
        sortOrder: sortOrder,
        onProgress: (int sent, int total) {
          if (!mounted || total <= 0) return;
          setState(() => pending.progress = sent / total);
        },
      );
      if (!mounted) return;
      setState(() => _pending.remove(pending));
      await provider.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Photo added.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on StorageValidationException catch (e) {
      if (mounted) setState(() => pending.error = e.message);
    } on ApiException catch (e) {
      if (mounted) setState(() => pending.error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(ListingMedia media) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => HivorrDialog(
        title: 'Delete photo?',
        content: const Text('This photo will be removed from the listing.'),
        actions: <Widget>[
          HivorrButton(
            label: 'Cancel',
            variant: HivorrButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HivorrButton(
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ServiceListingService service =
        context.read<ServiceListingService>();
    final ServiceListingProvider provider =
        context.read<ServiceListingProvider>();
    setState(() => _busy = true);
    try {
      await service.deleteMedia(
        mediaId: media.id,
        storagePath: media.storagePath,
      );
      await provider.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(
        title: Text(
          'Listing photos',
          style: context.textTheme.titleLarge,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _pickAndUpload,
        tooltip: 'Add photo',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: HivorrContentPane(
        child: Consumer2<ServiceListingProvider, ServiceListingService>(
          builder: (
            BuildContext context,
            ServiceListingProvider provider,
            ServiceListingService service,
            _,
          ) {
            if (provider.isLoading && !provider.isLoaded) {
              return const HivorrLoadingState(
                message: 'Loading photos…',
              );
            }
            if (provider.lastError != null && !provider.isLoaded) {
              return HivorrErrorState(
                message: 'Failed to load photos',
                detail: provider.lastError!.message,
                onRetry: () => provider.select(widget.listingId),
              );
            }
            final List<ListingMedia> media =
                provider.selected?.media ?? const <ListingMedia>[];
            if (media.isEmpty && _pending.isEmpty) {
              return HivorrEmptyState(
                icon: const Icon(Icons.photo_library_outlined),
                title: 'No photos yet',
                subtitle: 'Add photos to help buyers trust your service.',
                actionButton: HivorrButton(
                  label: 'Add photo',
                  onPressed: _pickAndUpload,
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: HivorrSpacing.sm,
                crossAxisSpacing: HivorrSpacing.sm,
                childAspectRatio: 0.85,
              ),
              itemCount: media.length + _pending.length,
              itemBuilder: (BuildContext context, int index) {
                if (index < media.length) {
                  final ListingMedia item = media[index];
                  return ListingMediaTile(
                    media: item,
                    imageUrl: service.mediaPublicUrl(item.storagePath),
                    onDelete: _busy ? null : () => _confirmDelete(item),
                  );
                }
                final _PendingUpload pending =
                    _pending[index - media.length];
                return ListingMediaTile(
                  imageUrl: null,
                  fileName: pending.fileName,
                  progress: pending.error == null
                      ? pending.progress
                      : null,
                  errorMessage: pending.error,
                  onRetry: () => _uploadPending(pending),
                  onDelete: () =>
                      setState(() => _pending.remove(pending)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
