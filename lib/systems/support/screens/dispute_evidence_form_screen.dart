import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/models/picked_evidence.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';

/// A user-selected evidence file, injected by the app shell via a real file
/// picker (mobile/Web `XFile.readAsBytes()`). Defaults to `null` (no picker
/// wired) which disables attachment submission.
typedef PickEvidenceCallback = Future<PickedEvidence?> Function();

/// Uploads [evidence] to the private `credential-documents` bucket and returns
/// the resulting storage path (may be `null` when no uploader is wired).
typedef UploadEvidenceCallback =
    Future<String?> Function(PickedEvidence evidence);

/// Evidence filing screen (EP-02-17 §5.7).
///
/// `GET /support/disputes/:caseId/evidence/new`. Renders the 4-type evidence
/// vocabulary, a 1–255 char title, an optional ≤2000 char description, and a
/// validated attachment picker (JPEG/PNG/WebP/PDF ≤10 MiB for
/// `credential-documents`). Uploads to the private bucket **before** calling
/// `dispute_submit_evidence`, mirroring the storage-before-RPC ordering of the
/// verification upload flow; `description`-type evidence needs no attachment.
class DisputeEvidenceFormScreen extends StatefulWidget {
  const DisputeEvidenceFormScreen({
    super.key,
    required this.caseId,
    this.pickFile,
    this.uploadFile,
  });

  /// The dispute case to attach evidence to.
  final String caseId;

  /// Injected file picker. When `null`, attachment types stay disabled.
  final PickEvidenceCallback? pickFile;

  /// Injected uploader (storage-before-RPC). When `null`, only
  /// `description`-type evidence can be submitted.
  final UploadEvidenceCallback? uploadFile;

  @override
  State<DisputeEvidenceFormScreen> createState() =>
      _DisputeEvidenceFormScreenState();
}

class _DisputeEvidenceFormScreenState extends State<DisputeEvidenceFormScreen> {
  EvidenceType? _type;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  PickedEvidence? _picked;
  String? _fieldError;
  String? _submitError;
  bool _uploading = false;
  bool _submitting = false;
  bool _succeeded = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _requiresFile => _type != null && !_isDescription(_type!.code);

  bool get _titleValid => DisputeService.validateTitle(_titleController.text);

  bool get _descriptionValid =>
      DisputeService.validateDescription(_descriptionController.text);

  bool get _attachmentReady =>
      _picked != null && widget.uploadFile != null && widget.pickFile != null;

  bool get _canSubmit =>
      !_submitting &&
      !_uploading &&
      !_succeeded &&
      _type != null &&
      _titleValid &&
      _descriptionValid &&
      (!_requiresFile || _attachmentReady);

  void _onTypeChanged(EvidenceType? type) {
    setState(() {
      _type = type;
      _fieldError = null;
      _submitError = null;
      if (type == null || _isDescription(type.code)) {
        _picked = null;
      }
    });
  }

  static bool _isDescription(String code) => code == 'description';

  Future<void> _pick() async {
    final callback = widget.pickFile;
    if (callback == null) return;
    final PickedEvidence? evidence = await callback();
    if (evidence == null) return;
    try {
      StorageValidators.validateForBucket(
        bucket: StorageBuckets.credentialDocuments,
        mimeType: evidence.mimeType,
        byteLength: evidence.bytes.length,
      );
      setState(() {
        _picked = evidence;
        _fieldError = null;
        _submitError = null;
      });
    } on Object catch (e) {
      setState(() {
        _fieldError = _friendlyPickError(e);
      });
    }
  }

  String _friendlyPickError(Object raw) {
    final String message = raw.toString();
    final String lower = message.toLowerCase();
    if (lower.contains('too large') || lower.contains('exceeds')) {
      return 'This file is too large — please use a file under 10 MB.';
    }
    return 'This file type is not supported. '
        'Please use JPG, PNG, WebP, or PDF.';
  }

  Future<void> _submit() async {
    final DisputeProvider provider = context.read<DisputeProvider>();
    final EvidenceType type = _type!;
    final String? path = await _upload(type);
    if (!mounted) return;
    if (_submittedWithError) {
      setState(() => _submitting = false);
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await provider.submitEvidence(
        caseId: widget.caseId,
        evidenceType: type.code,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        fileUrl: path,
        fileMetadata: path == null
            ? const <String, dynamic>{}
            : <String, dynamic>{
                'mimeType': _picked!.mimeType,
                'sizeBytes': _picked!.bytes.length,
                'originalName': _picked!.fileName,
              },
      );
      if (!mounted) return;
      setState(() => _succeeded = true);
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = error.toString();
      });
    }
  }

  /// Storage-before-RPC: uploads first when the evidence carries a file.
  ///
  /// Returns `null` for `description`-type evidence (no attachment). On upload
  /// failure sets [_submitError] and returns `null` — [submitEvidence] is never
  /// called with a partial upload.
  Future<String?> _upload(EvidenceType type) async {
    final PickedEvidence? picked = _picked;
    if (_isDescription(type.code)) {
      return null;
    }
    if (picked == null || widget.uploadFile == null) {
      setState(() => _submitError = 'No file selected to upload.');
      return null;
    }
    setState(() {
      _uploading = true;
      _submitError = null;
    });
    try {
      final String? path = await widget.uploadFile!(picked);
      if (!mounted) return null;
      setState(() {
        _uploading = false;
      });
      if (path == null) {
        setState(() => _submitError = 'Upload failed — please try again.');
      }
      return path;
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _submitError = error.toString();
        });
      }
      return null;
    }
  }

  /// Whether the upload step already surfaced an error via [_submitError].
  bool get _submittedWithError => _submitError != null;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add evidence', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: HivorrContentPane(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TypeField(selected: _type, onChanged: _onTypeChanged),
                const SizedBox(height: HivorrSpacing.md),
                TextField(
                  controller: _titleController,
                  maxLength: 255,
                  onChanged: (_) => setState(() => _submitError = null),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Signed delivery note, chat log…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: HivorrSpacing.md),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  minLines: 3,
                  maxLength: 2000,
                  onChanged: (_) => setState(() => _submitError = null),
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add context the reviewer should know…',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_requiresFile) ...[
                  const SizedBox(height: HivorrSpacing.md),
                  _AttachmentCard(
                    picked: _picked,
                    pickingEnabled: widget.pickFile != null,
                    uploading: _uploading,
                    fieldError: _fieldError,
                    onPick: _pick,
                  ),
                ],
                const SizedBox(height: HivorrSpacing.lg),
                HivorrButton(
                  label: 'Submit evidence',
                  isExpanded: true,
                  isLoading: _submitting || _uploading,
                  onPressed: _canSubmit ? () => unawaited(_submit()) : null,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: HivorrSpacing.md),
                  Text(
                    _submitError!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
                const SizedBox(height: HivorrSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: HivorrSpacing.xs),
                    Expanded(
                      child: Text(
                        'Evidence is recorded permanently and cannot be edited '
                        'or removed after submission.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeField extends StatelessWidget {
  const _TypeField({required this.selected, required this.onChanged});

  final EvidenceType? selected;
  final ValueChanged<EvidenceType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<EvidenceType>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Evidence type',
        border: OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<EvidenceType>>[
        for (final EvidenceType type in evidenceTypes)
          DropdownMenuItem<EvidenceType>(value: type, child: Text(type.label)),
      ],
      onChanged: (EvidenceType? type) => onChanged(type),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.picked,
    required this.pickingEnabled,
    required this.uploading,
    required this.onPick,
    this.fieldError,
  });

  final PickedEvidence? picked;
  final bool pickingEnabled;
  final bool uploading;
  final VoidCallback onPick;
  final String? fieldError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return HivorrCard(
      elevation: 0,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (picked == null)
            Center(
              child: HivorrButton(
                label: 'Choose file',
                variant: HivorrButtonVariant.outline,
                onPressed: pickingEnabled ? onPick : null,
                icon: const Icon(Icons.upload_file_outlined),
              ),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Icon(
                  picked!.mimeType == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: colors.primary,
                  size: 32,
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: Text(
                    picked!.fileName,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: pickingEnabled ? onPick : null,
                  tooltip: 'Choose a different file',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ],
          if (uploading) ...[
            const SizedBox(height: HivorrSpacing.sm),
            LinearProgressIndicator(
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ],
          if (fieldError != null && fieldError!.isNotEmpty) ...[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              fieldError!,
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}
