/// Public professional profile & trust-display system (EP-02-19).
///
/// Public surface for the Stage 7 trust output: the [ProfessionalProfileService]
/// facade (screen-only), the route screen, the read-only display widgets, and
/// the SEO meta builders. UI code in this barrel uses only [AppTheme] tokens
/// (AGENT.md Rule 5) — never Material color or font-family literals — and
/// renders only whitelisted RPC payload fields (never `legal_name` or
/// `document_path`).
library;

export 'package:hivorr/systems/portfolio/screens/professional_profile_screen.dart';
export 'package:hivorr/systems/portfolio/seo/portfolio_seo_meta.dart';
export 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';
export 'package:hivorr/systems/portfolio/widgets/credential_card.dart';
export 'package:hivorr/systems/portfolio/widgets/portfolio_grid.dart';
export 'package:hivorr/systems/portfolio/widgets/portfolio_item_card.dart';
export 'package:hivorr/systems/portfolio/widgets/profile_header_card.dart';
export 'package:hivorr/systems/portfolio/widgets/verification_badges_row.dart';
