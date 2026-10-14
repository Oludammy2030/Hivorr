import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/systems/identity/services/identity_resolver.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';
import 'package:provider/provider.dart';

/// A resolved counterparty face: the name to display plus an optional
/// caption (e.g. profession or business context).
class CounterpartyFace {
  const CounterpartyFace({required this.name, this.caption});

  /// The display name.
  final String name;

  /// Optional second line (role, business, or relationship context).
  final String? caption;
}

/// Role-appropriate counterparty label with async resolution
/// (identity audit Phase 5).
///
/// Shows [fallbackLabel] immediately (stable layout, no jump), swaps in the
/// resolved [CounterpartyFace] when [load] completes, and falls back on
/// error/empty. Resolution failures never surface raw errors — identity
/// display degrades to the deterministic fallback by design.
class CounterpartyIdentity extends StatefulWidget {
  const CounterpartyIdentity({
    super.key,
    required this.load,
    required this.fallbackLabel,
    this.textStyle,
    this.captionStyle,
  });

  /// Resolves the face; `null` keeps the fallback.
  final Future<CounterpartyFace?> Function() load;

  /// Deterministic label shown while loading and on any failure.
  final String fallbackLabel;

  /// Optional text styles (default to theme title/label styles).
  final TextStyle? textStyle;
  final TextStyle? captionStyle;

  @override
  State<CounterpartyIdentity> createState() => _CounterpartyIdentityState();
}

class _CounterpartyIdentityState extends State<CounterpartyIdentity> {
  CounterpartyFace? _face;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    try {
      final CounterpartyFace? face = await widget.load();
      if (!mounted) return;
      setState(() {
        _face = face;
        _settled = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _settled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CounterpartyFace? face = _settled ? _face : null;
    final String name = (face?.name.trim().isNotEmpty ?? false)
        ? face!.name
        : widget.fallbackLabel;
    final String? caption = face?.caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name,
          style:
              widget.textStyle ??
              context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null && caption.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            caption,
            style:
                widget.captionStyle ??
                context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Counterparty row for a service contract (identity audit Phase 5).
///
/// Client viewers resolve the professional's approved public face;
/// professional viewers resolve the hiring side from the linked job's
/// frozen client snapshots (business first, then individual). Strangers and
/// unresolvable rows render nothing — the role caption above stays the
/// source of truth for access, never this label.
class ContractCounterparty extends StatelessWidget {
  const ContractCounterparty({
    super.key,
    required this.contract,
    required this.viewerId,
  });

  /// The engagement under view.
  final ServiceContract contract;

  /// The viewing entity id.
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final bool isClient = viewerId == contract.clientEntityId;
    final bool isProfessional =
        viewerId == contract.professionalEntityId;
    if (!isClient && !isProfessional) {
      return const SizedBox.shrink();
    }
    if (isClient) {
      return CounterpartyIdentity(
        fallbackLabel: 'Professional',
        load: () => _professionalFace(context, contract.professionalEntityId),
      );
    }
    return CounterpartyIdentity(
      fallbackLabel: 'Client',
      load: () => _clientFace(context, contract),
    );
  }

  /// Resolves the professional face via the public profile (approved name
  /// first, derived display fallback). Returns `null` to keep the fallback
  /// when the provider is absent or the profile is gated.
  static Future<CounterpartyFace?> _professionalFace(
    BuildContext context,
    String professionalEntityId,
  ) async {
    try {
      final ProfessionalProfileService service = Provider.of<
        ProfessionalProfileService
      >(context, listen: false);
      final profile = await service.load(professionalEntityId);
      if (profile == null) return null;
      final ResolvedIdentity resolved =
          IdentityResolver.publicProfileHeadline(
            displayName: profile.displayName,
            professions: profile.professions,
          );
      return CounterpartyFace(name: resolved.name);
    } on Object {
      return null;
    }
  }

  /// Resolves the hiring side from the linked job's frozen snapshots
  /// (business first, then individual). Contracts without a job link, or
  /// unreadable jobs, keep the fallback — never a live profile lookup the
  /// viewer is not authorized for.
  static Future<CounterpartyFace?> _clientFace(
    BuildContext context,
    ServiceContract contract,
  ) async {
    try {
      final String? jobId = contract.jobId;
      if (jobId == null || jobId.isEmpty) return null;
      final JobProvider jobs = Provider.of<JobProvider>(
        context,
        listen: false,
      );
      final job = (await jobs.fetchJob(jobId)).job;
      final String? business = job.clientBusinessName?.trim();
      if (business != null && business.isNotEmpty) {
        return CounterpartyFace(
          name: business,
          caption: 'Hiring as a business',
        );
      }
      final String? individual = job.clientDisplayName?.trim();
      if (individual != null && individual.isNotEmpty) {
        return CounterpartyFace(name: individual);
      }
      return null;
    } on Object {
      return null;
    }
  }
}

/// Counterparty label for a message thread (identity audit Phase 5).
///
/// Professional viewers resolve the hiring side from the linked job's frozen
/// snapshots; client viewers resolve the professional's approved public
/// face. Threads without a hire, or any resolution failure, keep the
/// deterministic [fallbackPeer] label (`Professional …XXXX`).
class ThreadCounterparty extends StatelessWidget {
  const ThreadCounterparty({
    super.key,
    required this.hire,
    required this.viewerEntityId,
    required this.fallbackPeer,
    this.textStyle,
  });

  /// The hire linked to the thread, if resolved.
  final Hire? hire;

  /// The viewing entity id, if known.
  final String? viewerEntityId;

  /// Deterministic label while loading or on any failure.
  final String fallbackPeer;

  /// Optional text style for the resolved/fallback name.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final Hire? currentHire = hire;
    final String? viewer = viewerEntityId;
    if (currentHire == null || viewer == null || viewer.isEmpty) {
      return _fallbackText(context);
    }
    final bool viewerIsProfessional =
        viewer == currentHire.professionalEntityId;
    if (!viewerIsProfessional && viewer != currentHire.clientEntityId) {
      return _fallbackText(context);
    }
    if (viewerIsProfessional) {
      return CounterpartyIdentity(
        fallbackLabel: fallbackPeer,
        textStyle: textStyle,
        load: () => _clientFaceFromHire(context, currentHire),
      );
    }
    return CounterpartyIdentity(
      fallbackLabel: fallbackPeer,
      textStyle: textStyle,
      load: () => ContractCounterparty._professionalFace(
        context,
        currentHire.professionalEntityId,
      ),
    );
  }

  Widget _fallbackText(BuildContext context) {
    return Text(
      fallbackPeer,
      style:
          textStyle ??
          context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Resolves the hiring side from the hire's job snapshots (frozen at
  /// posting/submit; never a live profile read the viewer lacks).
  static Future<CounterpartyFace?> _clientFaceFromHire(
    BuildContext context,
    Hire hire,
  ) async {
    try {
      final JobProvider jobs = Provider.of<JobProvider>(
        context,
        listen: false,
      );
      final job = (await jobs.fetchJob(hire.jobId)).job;
      final String? business = job.clientBusinessName?.trim();
      if (business != null && business.isNotEmpty) {
        return CounterpartyFace(
          name: business,
          caption: 'Hiring as a business',
        );
      }
      final String? individual = job.clientDisplayName?.trim();
      if (individual != null && individual.isNotEmpty) {
        return CounterpartyFace(name: individual);
      }
      return null;
    } on Object {
      return null;
    }
  }
}

/// Reads the viewer entity id when a session is resolvable.
String? counterpartyViewerId(BuildContext context) {
  try {
    return Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentSession?.entityId;
  } on Object {
    return null;
  }
}
