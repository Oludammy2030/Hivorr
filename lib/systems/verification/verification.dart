/// Identity-verification business system (EP-02-10).
///
/// Public surface for the trust-gate feature: the document-type vocabulary,
/// the [IdentityVerificationService] facade, the reusable status widgets, and
/// the two screens. UI code in this barrel uses only [AppTheme] tokens
/// (AGENT.md Rule 5) — never `Colors.*`/hex/`fontFamily` literals.
library;

export 'package:hivorr/systems/verification/models/document_type.dart';
export 'package:hivorr/systems/verification/models/picked_document.dart';
export 'package:hivorr/systems/verification/screens/identity_document_upload_screen.dart';
export 'package:hivorr/systems/verification/screens/verification_status_screen.dart';
export 'package:hivorr/systems/verification/services/identity_verification_service.dart';
export 'package:hivorr/systems/verification/widgets/document_type_picker.dart';
export 'package:hivorr/systems/verification/widgets/identity_verified_badge.dart';
export 'package:hivorr/systems/verification/widgets/kyc_level_card.dart';
export 'package:hivorr/systems/verification/widgets/verification_timeline.dart';
