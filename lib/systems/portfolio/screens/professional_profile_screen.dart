import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/public_credential.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/providers/portfolio_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';
import 'package:hivorr/systems/portfolio/widgets/credential_card.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_grid.dart';
import 'package:hivorr/systems/portfolio/widgets/profile_header_card.dart';
import 'package:hivorr/systems/portfolio/widgets/verification_badges_row.dart';
import 'package:provider/provider.dart';

/// Public professional profile page at `/p/:slug/:id` (EP-02-19 §5.6, §5.7,
/// DoD FV-15/FV-21).
///
/// Reads `state.pathParameters['id']` (authoritative — the slug is cosmetic
/// SEO context), loads the profile through [ProfessionalProfileService] and
/// renders the header + verification badges + credentials + portfolio grid.
/// The screens state machine covers: loading (branded [HivorrLoadingState]),
/// not-found (`PLT004` → SEO-404 semantics, never echoing the id or legal
/// name), network/`PLT999` retry, and the loaded content. Responsive via
/// [HivorrContentPane] (16dp mobile gutters, capped web pane).
class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.profileId,
    this.routeSlug,
  });

  /// Entity UUID from the route (`:id`) — authoritative.
  final String profileId;

  /// Cosmetic, canonical `:slug` from the route (SEO context only).
  final String? routeSlug;

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  late final ProfessionalProfileService _service;
  bool _guardEmpty = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<ProfessionalProfileService>();
    if (widget.profileId.trim().isEmpty) {
      // FV-32: never issue a null/empty RPC param — not-found directly.
      _guardEmpty = true;
      return;
    }
    // Defer the load out of the build phase (load() notifies synchronously).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_guardEmpty) return;
    try {
      await _service.load(widget.profileId.trim());
    } on ApiException {
      // The provider already surfaced the normalized error; the screen
      // rebuilds off the provider state (retry via this same handler).
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider so state transitions rebuild the screen.
    context.watch<PortfolioProvider>();

    if (_guardEmpty) {
      return const _ScaffoldChild(child: _ProfileNotFoundView());
    }

    final PublicProfile? profile = _service.profile;

    if (_service.isLoading) {
      return const _ScaffoldChild(
        child: HivorrLoadingState(message: 'Loading profile…'),
      );
    }

    if (_service.state == PortfolioLoadState.error) {
      return _ScaffoldChild(child: _buildError(context));
    }

    if (_service.state == PortfolioLoadState.loaded) {
      if (profile == null) {
        return const _ScaffoldChild(child: _ProfileNotFoundView());
      }
      return _ScaffoldChild(child: _buildContent(context, profile));
    }

    return const _ScaffoldChild(
      child: HivorrLoadingState(message: 'Loading profile…'),
    );
  }

  Widget _buildError(BuildContext context) {
    final ApiException? error = _service.lastError;
    final String message = switch (error?.kind) {
      ApiExceptionKind.network || ApiExceptionKind.timeout =>
        'Unable to load this profile. Please check your connection.',
      ApiExceptionKind.validation =>
        'This profile link is not valid. Please try another link.',
      ApiExceptionKind.notFound => 'This profile could not be found.',
      _ => 'Something went wrong while loading this profile.',
    };
    return HivorrErrorState(
      message: message,
      onRetry: () => unawaited(_load()),
    );
  }

  Widget _buildContent(BuildContext context, PublicProfile profile) {
    final List<PublicCredential> credentials = _service.credentials;
    final bool hasCredentials = credentials.isNotEmpty;
    final bool hasPortfolio = profile.portfolioItems.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      children: <Widget>[
        ProfileHeaderCard(
          profile: profile,
          avatarUrl: _service.avatarPublicUrl(profile.avatarPath),
        ),
        const SizedBox(height: HivorrSpacing.lg),
        VerificationBadgesRow(
          identityVerified: _service.verifiedIdentity,
          tradeVerified: _service.tradeVerified,
          credentialCount: _service.verifiedCredentialCount,
          kycTierCode: _service.kycTierCode,
          kycStatus: _service.kycStatus,
        ),
        if (hasCredentials) ...<Widget>[
          const SizedBox(height: HivorrSpacing.lg),
          const HivorrSectionHeader(title: 'Credentials'),
          for (final PublicCredential credential in credentials) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
              child: CredentialCard(credential: credential),
            ),
          ],
        ],
        if (hasPortfolio) ...<Widget>[
          const SizedBox(height: HivorrSpacing.lg),
          const HivorrSectionHeader(title: 'Portfolio'),
          PortfolioGrid(
            items: profile.portfolioItems,
            mediaUrlBuilder: _resolveMediaUrl,
          ),
        ],
      ],
    );
  }

  String? _resolveMediaUrl(PortfolioItem item) {
    final String? path = item.mediaPath;
    if (path == null || path.isEmpty) return null;
    return _service.mediaPublicUrl(path);
  }
}

/// Scaffold shell shared by every screen state (route title stays generic —
/// the profile display name is rendered in the header card instead).
class _ScaffoldChild extends StatelessWidget {
  const _ScaffoldChild({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(child: HivorrContentPane(child: child)),
    );
  }
}

/// Clean not-found state with SEO-404 semantics — the same URL, no state leak,
/// no entity id or legal name echoed (DoD FV-23/FV-35, SV-03).
class _ProfileNotFoundView extends StatelessWidget {
  const _ProfileNotFoundView();

  @override
  Widget build(BuildContext context) {
    return HivorrEmptyState(
      icon: const Icon(Icons.person_search_outlined),
      title: 'Profile not found',
      subtitle:
          'This professional profile could not be found or is not currently '
          'public.',
    );
  }
}
