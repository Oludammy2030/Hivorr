import 'dart:typed_data';

import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

/// Resolves a readable display name for a bound [professionId].
///
/// Returns `null` when the name cannot be resolved; the submit flow falls back
/// to the proof type label in that case. Injectable so the data layer stays
/// free of a concrete taxonomy dependency (ARCHITECTURE.md unidirectional).
typedef TradeProfessionNameResolver = Future<String?> Function(
  String professionId,
);

/// Abstract contract for trade-verification data operations (EP-02-11 §5.3).
///
/// Depends only on domain entities and the [TradeProofType] vocabulary — never
/// on concrete backend types — so business systems and UI consume this
/// interface, not a Supabase implementation (ARCHITECTURE.md).
abstract class TradeVerificationRepository {
  /// Submits a trade proof for [professionId] and queues it for review.
  ///
  /// Orchestrates validate → private-bucket upload → `entity_credentials`
  /// insert (with `profession_id` binding) → `verification_submit('trade_proof')`
  /// queue. [bytes] is a platform-agnostic payload (from
  /// `XFile.readAsBytes()`), and [onProgress] reports bytes sent / total during
  /// upload.
  ///
  /// Throws [StorageValidationException] (`PLT003`) for invalid MIME/size
  /// before any network call, and [ApiException] with `kind == conflict`
  /// (`PLT005`) when an active submission already exists.
  Future<VerificationSubmission> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  });

  /// Fetches the trade-verification aggregate for the current entity.
  ///
  /// Backed by `verification_status_get`; `pending`/`rejected` per-profession
  /// states are derived client-side (decision log #2).
  Future<TradeVerificationStatus> getStatus();
}
