import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/providers/business_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/business/services/business_service.dart';
import 'package:provider/provider.dart';

/// Register a business identity (identity audit Phase 2a).
///
/// `GET /businesses/new`. Collects the public trading name, the registered
/// legal name, and the optional CAC number; creates the row then joins as
/// representative, and advances to the detail screen for verification.
/// A trading name here is never proof of registration — verification decides.
class BusinessFormScreen extends StatefulWidget {
  const BusinessFormScreen({super.key});

  @override
  State<BusinessFormScreen> createState() => _BusinessFormScreenState();
}

class _BusinessFormScreenState extends State<BusinessFormScreen> {
  final TextEditingController _trading = TextEditingController();
  final TextEditingController _legal = TextEditingController();
  final TextEditingController _cac = TextEditingController();
  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    _trading.dispose();
    _legal.dispose();
    _cac.dispose();
    super.dispose();
  }

  String? get _viewerId {
    try {
      return Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentSession?.entityId;
    } on Object {
      return null;
    }
  }

  Future<void> _save() async {
    final String trading = _trading.text.trim();
    final String legal = _legal.text.trim();
    final String cac = _cac.text.trim();
    final String? entityId = _viewerId;
    if (entityId == null || entityId.isEmpty) {
      setState(() => _formError = 'Sign in to add a business.');
      return;
    }
    if (!BusinessService.validateTradingName(trading)) {
      setState(
        () => _formError =
            'Business name is required (120 characters or fewer).',
      );
      return;
    }
    if (!BusinessService.validateLegalName(legal)) {
      setState(
        () => _formError =
            'Registered legal name is required (255 characters or fewer).',
      );
      return;
    }
    if (cac.isNotEmpty && !BusinessService.validateCacNumber(cac)) {
      setState(
        () => _formError = 'CAC number must be 64 characters or fewer.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final Business created = await context
          .read<BusinessProvider>()
          .create(
            entityId: entityId,
            tradingName: trading,
            registeredLegalName: legal,
            cacNumber: cac.isEmpty ? null : cac,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Business added. Submit documents to verify it.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
      context.pushReplacement(RoutePaths.businessDetail(created.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Add business')),
      body: HivorrContentPane(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
          children: <Widget>[
            HivorrCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Business identity',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The trading name is public. Registration is proven '
                    'by verification, not by typing a name.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            HivorrTextField(
              controller: _trading,
              label: 'Business / trading name',
              hint: 'e.g. Amara Foods',
              maxLength: BusinessService.maxTradingNameLength,
              onChanged: (_) => setState(() => _formError = null),
            ),
            const SizedBox(height: HivorrSpacing.md),
            HivorrTextField(
              controller: _legal,
              label: 'Registered legal name',
              hint: 'e.g. Amara Foods Ltd',
              maxLength: BusinessService.maxLegalNameLength,
              onChanged: (_) => setState(() => _formError = null),
            ),
            const SizedBox(height: HivorrSpacing.md),
            HivorrTextField(
              controller: _cac,
              label: 'CAC number (optional)',
              hint: 'e.g. RC123456',
              maxLength: BusinessService.maxCacLength,
              onChanged: (_) => setState(() => _formError = null),
            ),
            const SizedBox(height: HivorrSpacing.md),
            if (_formError != null)
              HivorrErrorState(
                message: 'Could not save this business',
                detail: _formError,
                onRetry: () => unawaited(_save()),
              ),
            if (_formError != null)
              const SizedBox(height: HivorrSpacing.sm),
            HivorrButton(
              label: 'Save business',
              onPressed: _saving ? null : () => unawaited(_save()),
              variant: HivorrButtonVariant.primary,
              isExpanded: true,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
