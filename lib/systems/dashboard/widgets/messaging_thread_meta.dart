import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/hire.dart';

/// Presentation metadata binding one message thread to its Service Request.
///
/// Every conversation is contract-scoped (exactly one thread per
/// `service_contracts` row). The displayed work title MUST come from the
/// [Hire] whose `contractId` matches the conversation — never a static
/// string shared across threads.
abstract final class MessagingThreadMeta {
  const MessagingThreadMeta._();

  /// The [Hire] linked to [conversation] via `contractId`, or `null` when
  /// the hire list has not hydrated (or the contract is unknown).
  static Hire? hireFor(List<Hire> hires, Conversation conversation) {
    if (conversation.contractId.isEmpty) return null;
    for (final Hire hire in hires) {
      if (hire.contractId == conversation.contractId) return hire;
    }
    return null;
  }

  /// The Service Request / work title for [conversation].
  ///
  /// Resolved per conversation from its linked hire's denormalized
  /// `jobTitle`; falls back to a short contract reference only when the
  /// hire is unknown.
  static String workTitleFor(List<Hire> hires, Conversation conversation) {
    final Hire? hire = hireFor(hires, conversation);
    final String? title = hire?.jobTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    final String contract = conversation.contractId;
    if (contract.isEmpty) return 'Service Request';
    final String short = contract.length <= 8
        ? contract
        : contract.substring(contract.length - 8);
    return 'Contract …$short';
  }

  /// Short contract reference for subtitles (`…` + last 8).
  static String contractShort(String contractId) {
    if (contractId.isEmpty) return '—';
    return contractId.length <= 8
        ? contractId
        : '…${contractId.substring(contractId.length - 8)}';
  }

  /// Display label for the other party.
  ///
  /// Messaging is E2EE with no directory lookup in scope, so the label is
  /// derived deterministically from the linked hire's professional id
  /// (mirrors the `Counterparty …suffix` pattern on disputes). Never a
  /// hardcoded person name.
  static String peerLabelFor(List<Hire> hires, Conversation conversation) {
    final Hire? hire = hireFor(hires, conversation);
    final String professionalId = hire?.professionalEntityId.trim() ?? '';
    if (professionalId.isEmpty) return 'Professional';
    final String short = professionalId.length <= 4
        ? professionalId
        : professionalId.substring(professionalId.length - 4);
    return 'Professional …$short';
  }

  /// Two-letter avatar initials for a peer label.
  static String peerInitials(String peerLabel) {
    final List<String> parts = peerLabel
        .replaceAll('…', ' ')
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'HI';
    if (parts.length == 1) {
      final String p = parts.first.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (p.isEmpty) return 'HI';
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    String initial(String s) {
      final String clean = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
      return clean.isEmpty ? '' : clean[0].toUpperCase();
    }

    final String result = '${initial(parts[0])}${initial(parts[1])}';
    return result.isEmpty ? 'HI' : result;
  }
}
