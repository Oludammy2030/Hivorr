/// EP-02-18 — Entity Registration & Onboarding Flow.
///
/// Barrel re-exporting the wizard system: models, service facade, screens and
/// widgets. Data-layer symbols (`OnboardingProgress`, stores, provider) live in
/// `lib/data/` and are re-exported through `lib/data/data_layer.dart`;
/// `OnboardingService` is consumed only by `OnboardingProvider`
/// (`lib/data/`), never by widgets (AGENT.md Rule 4).
library;

export 'package:hivorr/systems/onboarding/models/onboarding_step.dart';
export 'package:hivorr/systems/onboarding/models/picked_avatar.dart';
export 'package:hivorr/systems/onboarding/screens/identity_verification_step_screen.dart';
export 'package:hivorr/systems/onboarding/screens/industry_profession_selection_screen.dart';
export 'package:hivorr/systems/onboarding/screens/onboarding_complete_screen.dart';
export 'package:hivorr/systems/onboarding/screens/onboarding_shell_screen.dart';
export 'package:hivorr/systems/onboarding/screens/profile_setup_screen.dart';
export 'package:hivorr/systems/onboarding/screens/trade_proof_step_screen.dart';
export 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
export 'package:hivorr/systems/onboarding/widgets/onboarding_avatar_picker.dart';
export 'package:hivorr/systems/onboarding/widgets/onboarding_document_upload_tile.dart';
export 'package:hivorr/systems/onboarding/widgets/onboarding_exit_confirm_dialog.dart';
export 'package:hivorr/systems/onboarding/widgets/onboarding_progress_indicator.dart';
export 'package:hivorr/systems/onboarding/widgets/onboarding_step_card.dart';
export 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';