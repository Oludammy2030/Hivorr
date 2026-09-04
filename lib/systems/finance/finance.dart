/// Financial profile system barrel (EP-02-13).
///
/// Re-exports the finance module's public API for consumers. The
/// `lib/data/` layer owns DTOs/entities/repository/provider; the
/// `lib/systems/finance/` layer owns business vocabulary, service facade,
/// helpers, widgets, and screens.
library;

export 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
export 'package:hivorr/systems/finance/models/supported_currency.dart';
export 'package:hivorr/systems/finance/screens/financial_profile_creation_flow.dart';
export 'package:hivorr/systems/finance/screens/financial_profile_screen.dart';
export 'package:hivorr/systems/finance/services/financial_service.dart';
export 'package:hivorr/systems/finance/widgets/balance_chip.dart';
export 'package:hivorr/systems/finance/widgets/balance_overview_card.dart';
export 'package:hivorr/systems/finance/widgets/currency_account_card.dart';
export 'package:hivorr/systems/finance/widgets/financial_profile_card.dart';
