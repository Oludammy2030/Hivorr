/// Support system barrel (EP-02-17).
///
/// Re-exports the support module's public API for consumers. The
/// `lib/data/` layer owns DTOs/entities/repository/provider; the
/// `lib/systems/support/` layer owns business vocabulary, service facade,
/// helpers, widgets, and screens.
library;

export 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
export 'package:hivorr/systems/support/models/dispute_status.dart';
export 'package:hivorr/systems/support/models/picked_evidence.dart';
export 'package:hivorr/systems/support/screens/dispute_detail_screen.dart';
export 'package:hivorr/systems/support/screens/dispute_evidence_form_screen.dart';
export 'package:hivorr/systems/support/screens/dispute_filing_screen.dart';
export 'package:hivorr/systems/support/screens/dispute_list_screen.dart';
export 'package:hivorr/systems/support/services/dispute_service.dart';
export 'package:hivorr/systems/support/widgets/dispute_status_badge.dart';
export 'package:hivorr/systems/support/widgets/escrow_frozen_banner.dart';
export 'package:hivorr/systems/support/widgets/evidence_attachment_card.dart';