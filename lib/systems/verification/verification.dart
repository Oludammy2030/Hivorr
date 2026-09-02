/// Identity-verification + trade-verification business system (EP-02-10 / EP-02-11).
///
/// Public surface for the trust-gate feature: the document/proof-type
/// vocabularies, the [IdentityVerificationService]/[TradeVerificationService]
/// facades, the `TradeVerificationGate` bid-lock logic, the reusable status
/// widgets, and the screens. UI code in this barrel uses only [AppTheme] tokens
/// (AGENT.md Rule 5) — never Material color or font-family literals.
library;

export 'package:hivorr/systems/verification/gate/trade_verification_gate.dart';
export 'package:hivorr/systems/verification/models/document_type.dart';
export 'package:hivorr/systems/verification/models/picked_document.dart';
export 'package:hivorr/systems/verification/models/trade_proof_type.dart';
export 'package:hivorr/systems/verification/screens/admin_review_queue_screen.dart';
export 'package:hivorr/systems/verification/screens/identity_document_upload_screen.dart';
export 'package:hivorr/systems/verification/screens/trade_proof_upload_screen.dart';
export 'package:hivorr/systems/verification/screens/trade_verification_status_screen.dart';
export 'package:hivorr/systems/verification/screens/verification_status_screen.dart';
export 'package:hivorr/systems/verification/services/identity_verification_service.dart';
export 'package:hivorr/systems/verification/services/trade_verification_service.dart';
export 'package:hivorr/systems/verification/widgets/document_type_picker.dart';
export 'package:hivorr/systems/verification/widgets/identity_verified_badge.dart';
export 'package:hivorr/systems/verification/widgets/kyc_level_card.dart';
export 'package:hivorr/systems/verification/widgets/trade_proof_type_picker.dart';
export 'package:hivorr/systems/verification/widgets/trade_verification_timeline.dart';
export 'package:hivorr/systems/verification/widgets/trade_verified_badge.dart';
export 'package:hivorr/systems/verification/widgets/verification_timeline.dart';
