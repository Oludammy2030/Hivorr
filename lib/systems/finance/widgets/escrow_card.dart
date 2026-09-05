import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/models/escrow_status.dart';
import 'package:hivorr/systems/finance/widgets/escrow_status_badge.dart';

/// Per-escrow card on the list screen (EP-02-14 §5.6 / FV-46).
///
/// Shows the lifecycle badge, total + held amounts via [BalanceFormatter],
/// the external reference truncated to a `***last4` suffix (never full PII),
/// and the created date. Tapping [onTap] selects the escrow.
class EscrowCard extends StatelessWidget {
  const EscrowCard({
    super.key,
    required this.escrow,
    this.onTap,
  });

  final Escrow escrow;
  final VoidCallback? onTap;

  /// `***` + last 4 chars of the reference, or `***` when empty/null.
  static String truncateReference(String? reference) {
    if (reference == null || reference.isEmpty) return '***';
    if (reference.length <= 4) return '***$reference';
    return '***${reference.substring(reference.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final EscrowStatus? status = EscrowStatus.forCode(escrow.status);
    final String reference = truncateReference(escrow.externalReference);

    return HivorrCard(onTap: onTap, child: _CardBody(
      escrow: escrow,
      status: status,
      reference: reference,
    ));
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.escrow,
    required this.status,
    required this.reference,
  });

  final Escrow escrow;
  final EscrowStatus? status;
  final String reference;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                BalanceFormatter.formatBalance(
                  escrow.totalAmount,
                  escrow.currencyCode,
                ),
                style: context.textTheme.titleLarge,
              ),
            ),
            if (status != null) EscrowStatusBadge(status: status!),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Held: ${BalanceFormatter.formatBalance(escrow.heldAmount, escrow.currencyCode)}',
          style: context.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Ref $reference',
              style: context.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Text(
              '${escrow.createdAt.day}/${escrow.createdAt.month}/${escrow.createdAt.year}',
              style: context.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}