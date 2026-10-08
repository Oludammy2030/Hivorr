import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/config/wallet/wallet_conversion_rates_seed.dart';
import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/database/storage_engine.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/core/storage/supabase_storage_service.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
import 'package:hivorr/data/datasources/local/hive_service_search_local_data_source.dart';
import 'package:hivorr/data/datasources/local/messaging_local_data_source.dart';
import 'package:hivorr/data/datasources/local/service_search_local_data_source.dart';
import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/messaging_realtime_data_source.dart';
import 'package:hivorr/data/datasources/remote/scheduling_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/service_contract_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/service_listing_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/service_review_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/service_search_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_admin_review_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_conversion_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_dispute_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_escrow_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_deposit_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_payout_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_hires_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_jobs_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_kyc_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_manage_user_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_messaging_realtime_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_messaging_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_onboarding_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_scheduling_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_service_contract_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_service_listing_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_service_review_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_trade_verification_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_verification_remote_data_source.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/local/payout_account_local_store.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/conversion_provider.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/scheduling_provider.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/data/providers/service_review_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/data/repositories/admin_review_repository_impl.dart';
import 'package:hivorr/data/repositories/conversion_repository.dart';
import 'package:hivorr/data/repositories/conversion_repository_impl.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';
import 'package:hivorr/data/repositories/dispute_repository_impl.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';
import 'package:hivorr/data/repositories/escrow_repository.dart';
import 'package:hivorr/data/repositories/escrow_repository_impl.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository_impl.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/data/repositories/financial_payout_repository_impl.dart';
import 'package:hivorr/data/repositories/financial_repository.dart';
import 'package:hivorr/data/repositories/financial_repository_impl.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/hire_repository_impl.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/data/repositories/job_repository_impl.dart';
import 'package:hivorr/data/repositories/kyc_repository.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/data/repositories/manage_user_repository_impl.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/data/repositories/messaging_repository_impl.dart';
import 'package:hivorr/data/repositories/onboarding_repository.dart';
import 'package:hivorr/data/repositories/onboarding_repository_impl.dart';
import 'package:hivorr/data/repositories/scheduling_repository.dart';
import 'package:hivorr/data/repositories/scheduling_repository_impl.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';
import 'package:hivorr/data/repositories/service_contract_repository_impl.dart';
import 'package:hivorr/data/repositories/service_listing_repository.dart';
import 'package:hivorr/data/repositories/service_listing_repository_impl.dart';
import 'package:hivorr/data/repositories/service_review_repository.dart';
import 'package:hivorr/data/repositories/service_review_repository_impl.dart';
import 'package:hivorr/data/repositories/service_search_repository.dart';
import 'package:hivorr/data/repositories/service_search_repository_impl.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';
import 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/data/repositories/trade_verification_repository_impl.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/data/repositories/verification_repository_impl.dart';
import 'package:hivorr/engine/search_engine/service_search_index.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_factory.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_orchestrator.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';
import 'package:hivorr/systems/finance/services/conversion_service.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:hivorr/systems/reviews/services/service_review_service.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:hivorr/systems/verification/services/identity_verification_service.dart';
import 'package:hivorr/systems/verification/services/trade_verification_service.dart';
import 'package:hivorr/workspace/profession_registry/taxonomy_engine.dart';

export 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
export 'package:hivorr/data/datasources/local/hive_service_search_local_data_source.dart';
export 'package:hivorr/data/datasources/local/service_search_local_data_source.dart';
export 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
export 'package:hivorr/data/datasources/remote/conversion_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
export 'package:hivorr/data/datasources/remote/dispute_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/dispute_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/entity_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/escrow_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
export 'package:hivorr/data/datasources/remote/financial_deposit_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/financial_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/financial_payout_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/financial_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/hires_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/jobs_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/jobs_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/kyc_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/manage_user_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/messaging_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/messaging_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/onboarding_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/portfolio_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/portfolio_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/scheduling_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/scheduling_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/service_contract_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/service_contract_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/service_listing_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/service_listing_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/service_search_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/service_search_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_admin_review_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_conversion_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_dispute_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_escrow_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_financial_deposit_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_financial_payout_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_financial_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_hires_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_jobs_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_kyc_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_manage_user_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_messaging_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_onboarding_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_portfolio_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_scheduling_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_service_contract_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_service_listing_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_trade_verification_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_verification_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/taxonomy_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/trade_verification_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/verification_remote_data_source.dart';
export 'package:hivorr/data/entities/appointment.dart';
export 'package:hivorr/data/entities/appointment_event.dart';
export 'package:hivorr/data/entities/availability_slot.dart';
export 'package:hivorr/data/entities/balance.dart';
export 'package:hivorr/data/entities/contract_event.dart';
export 'package:hivorr/data/entities/contract_milestone.dart';
export 'package:hivorr/data/entities/conversation.dart';
export 'package:hivorr/data/entities/conversion_preview.dart';
export 'package:hivorr/data/entities/currency_account.dart';
export 'package:hivorr/data/entities/currency_conversion.dart';
export 'package:hivorr/data/entities/deposit.dart';
export 'package:hivorr/data/entities/dispute_case.dart';
export 'package:hivorr/data/entities/dispute_evidence.dart';
export 'package:hivorr/data/entities/dispute_resolution.dart';
export 'package:hivorr/data/entities/entity.dart';
export 'package:hivorr/data/entities/entity_profile.dart';
export 'package:hivorr/data/entities/entity_role.dart';
export 'package:hivorr/data/entities/escrow.dart';
export 'package:hivorr/data/entities/escrow_detail.dart';
export 'package:hivorr/data/entities/escrow_milestone.dart';
export 'package:hivorr/data/entities/escrow_transaction.dart';
export 'package:hivorr/data/entities/financial_profile.dart';
export 'package:hivorr/data/entities/financial_status.dart';
export 'package:hivorr/data/entities/hire.dart';
export 'package:hivorr/data/entities/industry.dart';
export 'package:hivorr/data/entities/job.dart';
export 'package:hivorr/data/entities/job_application.dart';
export 'package:hivorr/data/entities/job_quotation.dart';
export 'package:hivorr/data/entities/kyc_level.dart';
export 'package:hivorr/data/entities/listing_media.dart';
export 'package:hivorr/data/entities/onboarding_progress.dart';
export 'package:hivorr/data/entities/onboarding_status.dart';
export 'package:hivorr/data/entities/payout_account.dart';
export 'package:hivorr/data/entities/portfolio_item.dart';
export 'package:hivorr/data/entities/profession.dart';
export 'package:hivorr/data/entities/public_credential.dart';
export 'package:hivorr/data/entities/public_profession.dart';
export 'package:hivorr/data/entities/public_profile.dart';
export 'package:hivorr/data/entities/service_contract.dart';
export 'package:hivorr/data/entities/service_listing.dart';
export 'package:hivorr/data/entities/trade_verification_status.dart';
export 'package:hivorr/data/entities/verification_status.dart';
export 'package:hivorr/data/entities/verification_submission.dart';
export 'package:hivorr/data/entities/withdrawal_result.dart';
export 'package:hivorr/data/local/onboarding_progress_store.dart';
export 'package:hivorr/data/local/payout_account_local_store.dart';
export 'package:hivorr/data/mappers/contract_mapper.dart';
export 'package:hivorr/data/mappers/conversion_mapper.dart';
export 'package:hivorr/data/mappers/dispute_mapper.dart';
export 'package:hivorr/data/mappers/entity_mapper.dart';
export 'package:hivorr/data/mappers/entity_profile_mapper.dart';
export 'package:hivorr/data/mappers/entity_role_mapper.dart';
export 'package:hivorr/data/mappers/escrow_mapper.dart';
export 'package:hivorr/data/mappers/financial_deposit_mapper.dart';
export 'package:hivorr/data/mappers/financial_mapper.dart';
export 'package:hivorr/data/mappers/financial_payout_mapper.dart';
export 'package:hivorr/data/mappers/hire_mapper.dart';
export 'package:hivorr/data/mappers/industry_mapper.dart';
export 'package:hivorr/data/mappers/job_mapper.dart';
export 'package:hivorr/data/mappers/messaging_mapper.dart';
export 'package:hivorr/data/mappers/onboarding_status_mapper.dart';
export 'package:hivorr/data/mappers/portfolio_mappers.dart';
export 'package:hivorr/data/mappers/profession_mapper.dart';
export 'package:hivorr/data/mappers/scheduling_mapper.dart';
export 'package:hivorr/data/mappers/service_listing_mapper.dart';
export 'package:hivorr/data/mappers/verification_mapper.dart';
export 'package:hivorr/data/models/balance_dto.dart';
export 'package:hivorr/data/models/contract_envelopes_dto.dart';
export 'package:hivorr/data/models/contract_event_dto.dart';
export 'package:hivorr/data/models/contract_milestone_dto.dart';
export 'package:hivorr/data/models/conversation_dto.dart';
export 'package:hivorr/data/models/conversion_preview_dto.dart';
export 'package:hivorr/data/models/currency_conversion_dto.dart';
export 'package:hivorr/data/models/deposit_dto.dart';
export 'package:hivorr/data/models/dispute_case_detail.dart';
export 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
export 'package:hivorr/data/models/dispute_case_dto.dart';
export 'package:hivorr/data/models/dispute_evidence_dto.dart';
export 'package:hivorr/data/models/dispute_list_envelope_dto.dart';
export 'package:hivorr/data/models/dispute_resolution_dto.dart';
export 'package:hivorr/data/models/entity_dto.dart';
export 'package:hivorr/data/models/entity_profile_dto.dart';
export 'package:hivorr/data/models/entity_role_dto.dart';
export 'package:hivorr/data/models/escrow_detail_dto.dart';
export 'package:hivorr/data/models/escrow_dto.dart';
export 'package:hivorr/data/models/escrow_milestone_dto.dart';
export 'package:hivorr/data/models/escrow_milestone_input.dart';
export 'package:hivorr/data/models/escrow_transaction_dto.dart';
export 'package:hivorr/data/models/financial_profile_dto.dart';
export 'package:hivorr/data/models/financial_status_dto.dart';
export 'package:hivorr/data/models/hire_dto.dart';
export 'package:hivorr/data/models/hire_envelopes_dto.dart';
export 'package:hivorr/data/models/industry_dto.dart';
export 'package:hivorr/data/models/job_application_dto.dart';
export 'package:hivorr/data/models/job_dto.dart';
export 'package:hivorr/data/models/job_envelopes_dto.dart';
export 'package:hivorr/data/models/job_quotation_dto.dart';
export 'package:hivorr/data/models/kyc_level_dto.dart';
export 'package:hivorr/data/models/listing_media_dto.dart';
export 'package:hivorr/data/models/manage_user_dto.dart';
export 'package:hivorr/data/models/messaging_envelopes_dto.dart';
export 'package:hivorr/data/models/onboarding_status_dto.dart';
export 'package:hivorr/data/models/payout_bind_dto.dart';
export 'package:hivorr/data/models/portfolio_item_dto.dart';
export 'package:hivorr/data/models/profession_dto.dart';
export 'package:hivorr/data/models/public_credential_dto.dart';
export 'package:hivorr/data/models/public_profession_dto.dart';
export 'package:hivorr/data/models/public_profile_dto.dart';
export 'package:hivorr/data/models/scheduling_dto.dart';
export 'package:hivorr/data/models/scheduling_envelopes_dto.dart';
export 'package:hivorr/data/models/service_contract_dto.dart';
export 'package:hivorr/data/models/service_listing_dto.dart';
export 'package:hivorr/data/models/trade_verification_dto.dart';
export 'package:hivorr/data/models/verification_status_dto.dart';
export 'package:hivorr/data/models/verification_submission_dto.dart';
export 'package:hivorr/data/models/withdrawal_dto.dart';
export 'package:hivorr/data/providers/admin_config_provider.dart';
export 'package:hivorr/data/providers/admin_review_provider.dart';
export 'package:hivorr/data/providers/conversion_provider.dart';
export 'package:hivorr/data/providers/dispute_provider.dart';
export 'package:hivorr/data/providers/entity_provider.dart';
export 'package:hivorr/data/providers/escrow_provider.dart';
export 'package:hivorr/data/providers/financial_deposit_provider.dart';
export 'package:hivorr/data/providers/financial_payout_provider.dart';
export 'package:hivorr/data/providers/financial_provider.dart';
export 'package:hivorr/data/providers/hire_provider.dart';
export 'package:hivorr/data/providers/job_provider.dart';
export 'package:hivorr/data/providers/kyc_provider.dart';
export 'package:hivorr/data/providers/manage_user_provider.dart';
export 'package:hivorr/data/providers/marketplace_search_provider.dart';
export 'package:hivorr/data/providers/messaging_provider.dart';
export 'package:hivorr/data/providers/onboarding_provider.dart';
export 'package:hivorr/data/providers/portfolio_provider.dart';
export 'package:hivorr/data/providers/scheduling_provider.dart';
export 'package:hivorr/data/providers/service_contract_provider.dart';
export 'package:hivorr/data/providers/service_listing_provider.dart';
export 'package:hivorr/data/providers/submit_state.dart';
export 'package:hivorr/data/providers/taxonomy_provider.dart';
export 'package:hivorr/data/providers/trade_verification_provider.dart';
export 'package:hivorr/data/providers/verification_provider.dart';
export 'package:hivorr/data/repositories/admin_review_repository.dart';
export 'package:hivorr/data/repositories/admin_review_repository_impl.dart';
export 'package:hivorr/data/repositories/conversion_repository.dart';
export 'package:hivorr/data/repositories/conversion_repository_impl.dart';
export 'package:hivorr/data/repositories/dispute_repository.dart';
export 'package:hivorr/data/repositories/dispute_repository_impl.dart';
export 'package:hivorr/data/repositories/entity_repository.dart';
export 'package:hivorr/data/repositories/entity_repository_impl.dart';
export 'package:hivorr/data/repositories/escrow_repository.dart';
export 'package:hivorr/data/repositories/escrow_repository_impl.dart';
export 'package:hivorr/data/repositories/financial_deposit_repository.dart';
export 'package:hivorr/data/repositories/financial_deposit_repository_impl.dart';
export 'package:hivorr/data/repositories/financial_payout_repository.dart';
export 'package:hivorr/data/repositories/financial_payout_repository_impl.dart';
export 'package:hivorr/data/repositories/financial_repository.dart';
export 'package:hivorr/data/repositories/financial_repository_impl.dart';
export 'package:hivorr/data/repositories/hire_repository.dart';
export 'package:hivorr/data/repositories/hire_repository_impl.dart';
export 'package:hivorr/data/repositories/job_repository.dart';
export 'package:hivorr/data/repositories/job_repository_impl.dart';
export 'package:hivorr/data/repositories/kyc_repository.dart';
export 'package:hivorr/data/repositories/kyc_repository_impl.dart';
export 'package:hivorr/data/repositories/manage_user_repository.dart';
export 'package:hivorr/data/repositories/manage_user_repository_impl.dart';
export 'package:hivorr/data/repositories/messaging_repository.dart';
export 'package:hivorr/data/repositories/messaging_repository_impl.dart';
export 'package:hivorr/data/repositories/onboarding_repository.dart';
export 'package:hivorr/data/repositories/onboarding_repository_impl.dart';
export 'package:hivorr/data/repositories/portfolio_repository.dart';
export 'package:hivorr/data/repositories/portfolio_repository_impl.dart';
export 'package:hivorr/data/repositories/scheduling_repository.dart';
export 'package:hivorr/data/repositories/scheduling_repository_impl.dart';
export 'package:hivorr/data/repositories/service_contract_repository.dart';
export 'package:hivorr/data/repositories/service_contract_repository_impl.dart';
export 'package:hivorr/data/repositories/service_listing_repository.dart';
export 'package:hivorr/data/repositories/service_listing_repository_impl.dart';
export 'package:hivorr/data/repositories/service_search_repository.dart';
export 'package:hivorr/data/repositories/service_search_repository_impl.dart';
export 'package:hivorr/data/repositories/taxonomy_repository.dart';
export 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';
export 'package:hivorr/data/repositories/trade_verification_repository.dart';
export 'package:hivorr/data/repositories/trade_verification_repository_impl.dart';
export 'package:hivorr/data/repositories/verification_repository.dart';
export 'package:hivorr/data/repositories/verification_repository_impl.dart';
export 'package:hivorr/systems/communication/services/message_crypto.dart';
export 'package:hivorr/systems/communication/services/messaging_service.dart';
export 'package:hivorr/systems/jobs/models/job_status.dart';
export 'package:hivorr/systems/jobs/services/hire_service.dart';
export 'package:hivorr/systems/jobs/services/job_service.dart';
export 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
export 'package:hivorr/systems/support/services/dispute_service.dart';

/// Wires the Unified Data Access Layer for the active environment.
///
/// Consumes the [ApiLayer] produced by [ApiInitializer.initializeApi]
/// (EP-01-07) and returns a fully constructed [EntityProvider] ready for
/// EP-01-15 to place in the widget tree. `main.dart`/bootstrap is not
/// modified here (EP-01-08 §5.8).
EntityProvider registerDataLayer(ApiLayer apiLayer) {
  final remote = SupabaseEntityRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final local = InMemoryEntityLocalDataSource();
  final repository = EntityRepositoryImpl(remote: remote, local: local);
  return EntityProvider(repository: repository);
}

/// Wires the taxonomy (industry/profession) data slice for EP-02-07.
///
/// Builds the [TaxonomyRepository] (cache-first) and returns a ready
/// [TaxonomyProvider]. The repository's local datasource degrades gracefully
/// to in-memory storage until the app initializes the shared [CacheManager].
/// Exposed for the bootstrap to register in the widget tree's MultiProvider
/// (EP-02-07 plan §17 criterion 21).
///
/// Returns both the repository and provider so callers can provide the
/// repository as a `Provider<TaxonomyRepository>` alongside the
/// `ChangeNotifierProvider<TaxonomyProvider>`.
({TaxonomyRepository repository, TaxonomyProvider provider})
registerTaxonomyLayer(ApiLayer apiLayer) {
  final remote = SupabaseTaxonomyRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final local = CacheManagerTaxonomyLocalDataSource();
  final repository = TaxonomyRepositoryImpl(remote: remote, local: local);
  return (
    repository: repository,
    provider: TaxonomyProvider(repository: repository),
  );
}

/// Wires the ranked marketplace-search data slice for EP-03-07.
///
/// Builds the [ServiceSearchRepository] (browse cache-first, FTS
/// network-first) over the single `service_ranking_search` RPC seam and
/// returns a ready [MarketplaceSearchProvider] plus the [ServiceSearchIndex]
/// offline-browse hydrator. Mirrors `registerTaxonomyLayer`: ordering stays
/// server-decided (`AGENT.md:7`), the client never resorts `items`.
///
/// The local datasource degrades gracefully: when [storageEngine] is supplied
/// the [HiveServiceSearchLocalDataSource] persists ranked pages across
/// restarts (fronted by the shared [CacheManager] when initialized),
/// otherwise the transient `CacheManagerServiceSearchLocalDataSource`
/// (in-memory fallback until the app initializes the shared cache).
/// Exposed for the bootstrap to register in the widget tree's MultiProvider
/// (consumer: EP-03-09 discovery screens).
///
/// Returns repository, provider, and index so callers can provide the
/// repository as a `Provider<ServiceSearchRepository>` alongside the
/// `ChangeNotifierProvider<MarketplaceSearchProvider>`.
/// No new `GIN`/`search_vector` DDL — FTS composes the EP-03-01 trigger +
/// `GIN(search_vector)` via the EP-03-06 ranking RPC (plan §7.1).
({
  ServiceSearchRepository repository,
  MarketplaceSearchProvider provider,
  ServiceSearchIndex index,
})
registerMarketplaceSearchLayer(
  ApiLayer apiLayer, {
  required TaxonomyRepository taxonomyRepository,
  StorageEngine? storageEngine,
}) {
  final remote = SupabaseServiceSearchRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final ServiceSearchLocalDataSource local = HiveServiceSearchLocalDataSource(
    store: storageEngine != null ? LocalStore(storageEngine) : null,
    cache: CacheManager.isInitialized ? CacheManager.instance : null,
  );
  final repository = ServiceSearchRepositoryImpl(remote: remote, local: local);
  return (
    repository: repository,
    provider: MarketplaceSearchProvider(repository: repository),
    index: ServiceSearchIndex(
      repository: repository,
      taxonomy: TaxonomyEngine(repository: taxonomyRepository),
    ),
  );
}

/// Wires the identity-verification data slice for EP-02-10.
///
/// Builds the [SupabaseStorageService] (object store) and
/// [VerificationRepository] over the [ApiLayer] and returns a ready
/// [VerificationProvider]. Exposed for the bootstrap to register in the
/// widget tree's MultiProvider (mirrors `registerTaxonomyLayer`).
///
/// The storage service uses the injected API-layer [Dio] for progress-aware
/// uploads to the private `credential-documents` bucket (server-authoritative).
({VerificationRepository repository, VerificationProvider provider})
registerVerificationLayer(ApiLayer apiLayer) {
  final remote = SupabaseVerificationRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final storage = SupabaseStorageService(
    storageClient: apiLayer.supabaseClient.storage,
    dio: apiLayer.dio,
    tokenProvider: apiLayer.tokenProvider,
  );
  final repository = VerificationRepositoryImpl(
    remote: remote,
    storage: storage,
    supabase: apiLayer.supabaseClient,
  );
  return (
    repository: repository,
    provider: VerificationProvider(repo: repository),
  );
}

/// Wires the trade-verification data slice for EP-02-11.
///
/// Builds the [SupabaseStorageService] (object store) and
/// [TradeVerificationRepository] over the [ApiLayer] and returns a ready
/// [TradeVerificationProvider]. Exposed for the bootstrap to register in the
/// widget tree's MultiProvider (mirrors `registerVerificationLayer`).
///
/// The storage service uses the injected API-layer [Dio] for progress-aware
/// uploads to the private `credential-documents` bucket (server-authoritative).
({TradeVerificationRepository repository, TradeVerificationProvider provider})
registerTradeVerificationLayer(ApiLayer apiLayer) {
  final remote = SupabaseTradeVerificationRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final storage = SupabaseStorageService(
    storageClient: apiLayer.supabaseClient.storage,
    dio: apiLayer.dio,
    tokenProvider: apiLayer.tokenProvider,
  );
  final repository = TradeVerificationRepositoryImpl(
    remote: remote,
    storage: storage,
    supabase: apiLayer.supabaseClient,
  );
  return (
    repository: repository,
    provider: TradeVerificationProvider(repo: repository),
  );
}

/// Wires the admin-review data slice for EP-02-11.
///
/// Builds the [AdminReviewRepository] over the [ApiLayer] and returns a ready
/// [AdminReviewProvider]. Exposed for the bootstrap to register in the widget
/// tree's MultiProvider (mirrors `registerTradeVerificationLayer`).
///
/// Admin authorization is enforced server-side by `is_platform_admin()`; the
/// provider caches the admin flag for the current session only.
({AdminReviewRepository repository, AdminReviewProvider provider})
registerAdminReviewLayer(ApiLayer apiLayer) {
  final remote = SupabaseAdminReviewRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = AdminReviewRepositoryImpl(remote: remote);
  return (
    repository: repository,
    provider: AdminReviewProvider(repo: repository),
  );
}

/// Wires the Manage User (admin console) data slice for EP-02-11.
///
/// Builds the [ManageUserRepository] over the [ApiLayer] and returns a ready
/// [ManageUserProvider]. Exposed for the bootstrap to register in the widget
/// tree's MultiProvider (mirrors `registerAdminReviewLayer`).
///
/// Admin authorization is enforced server-side by `is_platform_admin()`; the
/// router guard and screens gate the `/admin/users` routes with the shared
/// [AdminGate] over the admin-review provider.
({ManageUserRepository repository, ManageUserProvider provider})
registerManageUserLayer(ApiLayer apiLayer) {
  final remote = SupabaseManageUserRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = ManageUserRepositoryImpl(remote: remote);
  return (
    repository: repository,
    provider: ManageUserProvider(repo: repository),
  );
}

/// Wires the KYC data slice for EP-02-12.
///
/// Builds the [KycRepository] over the [ApiLayer] and returns a ready
/// [KycProvider]. Exposed for the bootstrap to register in the widget tree's
/// MultiProvider (mirrors `registerVerificationLayer`).
({KycRepository repository, KycProvider provider}) registerKycLayer(
  ApiLayer apiLayer,
) {
  final remote = SupabaseKycRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = KycRepositoryImpl(remote: remote);
  return (repository: repository, provider: KycProvider(repo: repository));
}

/// Wires the financial-profile data slice for EP-02-13.
///
/// Builds the [FinancialRepository] over the [ApiLayer] and returns a ready
/// [FinancialProvider] bound to a [FinancialService] facade. Exposed for the
/// bootstrap to register in the widget tree's MultiProvider (mirrors
/// `registerKycLayer`).
({FinancialRepository repository, FinancialProvider provider})
registerFinancialLayer(
  ApiLayer apiLayer, {
  PaymentGatewayFactory? paymentGatewayFactory,
}) {
  final remote = SupabaseFinancialRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = FinancialRepositoryImpl(
    remote: remote,
    paymentGatewayFactory: paymentGatewayFactory,
  );
  final service = FinancialService(repository: repository);
  return (
    repository: repository,
    provider: FinancialProvider(service: service),
  );
}

/// Wires the payout-account data slice for EP-02-16.
///
/// Builds the [FinancialPayoutRepository] over the [ApiLayer] (bind + withdraw
/// via the authenticated RPCs) backed by an injectable
/// [PayoutAccountLocalStore] display mirror, and returns a ready
/// [FinancialPayoutProvider] bound to a [FinancialPayoutService] facade.
({FinancialPayoutRepository repository, FinancialPayoutProvider provider})
registerPayoutLayer(ApiLayer apiLayer, {PayoutAccountLocalStore? store}) {
  final remote = SupabaseFinancialPayoutRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = FinancialPayoutRepositoryImpl(
    remote: remote,
    store: store ?? InMemoryPayoutAccountLocalStore(),
  );
  final service = FinancialPayoutService(repository: repository);
  return (
    repository: repository,
    provider: FinancialPayoutProvider(service: service),
  );
}

/// Wires the deposit-read data slice for EP-02-16.
///
/// Builds the [FinancialDepositRepository] over the [ApiLayer] (RLS-scoped
/// REST select on `financial_deposits`) and returns a ready
/// [FinancialDepositProvider] bound to a [FinancialDepositService] facade.
/// Read-only — deposit recording/name verification stays service-role.
({FinancialDepositRepository repository, FinancialDepositProvider provider})
registerDepositLayer(ApiLayer apiLayer) {
  final remote = SupabaseFinancialDepositRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = FinancialDepositRepositoryImpl(remote: remote);
  final service = FinancialDepositService(repository: repository);
  return (
    repository: repository,
    provider: FinancialDepositProvider(service: service),
  );
}

/// Wires the escrow data slice for EP-02-14.
///
/// Builds the [EscrowRepository] and [EscrowService] over the [ApiLayer] and
/// returns a ready [EscrowProvider] bound to the write-proxy seam
/// ([writeViaProxy] — from `AppConfig.escrowWriteViaProxyEnabled`, default
/// `false`). Exposed for the bootstrap to register in the widget tree's
/// MultiProvider (mirrors `registerFinancialLayer`).
({EscrowRepository repository, EscrowProvider provider}) registerEscrowLayer(
  ApiLayer apiLayer, {
  bool writeViaProxy = false,
}) {
  final remote = SupabaseEscrowRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
    writeViaProxy: writeViaProxy,
  );
  final repository = EscrowRepositoryImpl(remote: remote);
  final service = EscrowService(repository: repository);
  return (repository: repository, provider: EscrowProvider(service: service));
}

/// Wires the currency-conversion data slice for EP-02-15.
///
/// Builds the [ConversionRepository] over the [ApiLayer] with the single
/// client rate authority ([ConfigConversionRateSource] over
/// [WalletConversionPairsConfig]) and returns a ready [ConversionProvider]
/// bound to a [ConversionService] facade. Exposed for the bootstrap to
/// register in the widget tree's MultiProvider (mirrors
/// `registerEscrowLayer`).
///
/// [financialRepository] is required for the post-execute balance refresh
/// (`financial_status_get`); a missing pair rate fails closed through
/// [ConversionRateUnavailableException]. `historyReadEnabled` gates the
/// `financial_conversions` REST read seam (build-time decision, §5.2).
({ConversionRepository repository, ConversionProvider provider})
registerConversionLayer(
  ApiLayer apiLayer, {
  required FinancialRepository financialRepository,
  WalletConversionPairsConfig? pairsConfig,
  bool historyReadEnabled = true,
}) {
  final remote = SupabaseConversionRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
    historyReadEnabled: historyReadEnabled,
  );
  final WalletConversionPairsConfig config =
      pairsConfig ??
      const WalletConversionPairsConfig(
        baseCrossRates: WalletConversionRatesSeed.baseCrossRates,
      );
  final ConversionRateSource rateSource = ConfigConversionRateSource(config);
  final repository = ConversionRepositoryImpl(
    remote: remote,
    rateSource: rateSource,
    financialRepository: financialRepository,
  );
  final service = ConversionService(
    repository: repository,
    pairsConfig: config,
  );
  final provider = ConversionProvider(
    service: service,
    financialService: FinancialService(repository: financialRepository),
  );
  return (repository: repository, provider: provider);
}

/// Wires the dispute-resolution data slice for EP-02-17.
///
/// Builds the [DisputeRepository] and [DisputeService] over the [ApiLayer] and
/// returns a ready [DisputeProvider]. Mirrors `registerEscrowLayer`: all five
/// authenticated RPCs are live, reads are RLS-scoped, and filing/withdrawing
/// freeze/release the escrow server-side — the client never writes tables and
/// never references the service-role-only `dispute_resolve`.
({DisputeRepository repository, DisputeProvider provider}) registerDisputeLayer(
  ApiLayer apiLayer,
) {
  final remote = SupabaseDisputeRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = DisputeRepositoryImpl(remote: remote);
  final service = DisputeService(repository: repository);
  return (repository: repository, provider: DisputeProvider(service: service));
}

/// Wires the service listing owner-management slice for EP-03-08.
///
/// Builds the [ServiceListingRepository] and [ServiceListingService] over
/// the [ApiLayer] and returns a ready [ServiceListingProvider]. Mirrors
/// `registerDisputeLayer`: all six owner RPCs are live, reads are RLS-scoped,
/// and the trade gate stays server-side — the client never writes
/// `service_listings` tables and never references the service-role-only
/// `reported` transition.
({
  ServiceListingRepository repository,
  ServiceListingProvider provider,
  ServiceListingService service,
})
registerServiceListingLayer(
  ApiLayer apiLayer, {
  ServiceListingRemoteDataSource? dataSource,
  StorageService? storage,
  HivorrLogger? logger,
}) {
  final ServiceListingRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseServiceListingRemoteDataSource(
        dio: apiLayer.dio,
        supabase: apiLayer.supabaseClient,
        exceptionMapper: apiLayer.exceptionMapper,
      );
  final ServiceListingRepository repository = ServiceListingRepositoryImpl(
    remote: resolvedDataSource,
  );
  final ServiceListingService service = ServiceListingService(
    repository: repository,
    supabase: apiLayer.supabaseClient,
    storage: storage,
    logger: logger,
  );
  return (
    repository: repository,
    provider: ServiceListingProvider(service: service, logger: logger),
    service: service,
  );
}

/// Wires the service contract engagement slice for EP-03-10.
///
/// Builds the [ServiceContractRepository] and [ContractService] over
/// the [ApiLayer] and returns a ready [ServiceContractProvider]. Mirrors
/// `registerServiceListingLayer`: all eight contract RPCs are live, reads are
/// RLS participant-scoped, evidence uploads use the `service-listing-media`
/// owner prefix — the client never writes contract tables and never funds or
/// releases escrow (EP-03-11 owns fund movement).
({
  ServiceContractRepository repository,
  ServiceContractProvider provider,
  ContractService service,
})
registerServiceContractLayer(
  ApiLayer apiLayer, {
  ServiceContractRemoteDataSource? dataSource,
  StorageService? storage,
  HivorrLogger? logger,
}) {
  final ServiceContractRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseServiceContractRemoteDataSource(
        dio: apiLayer.dio,
        supabase: apiLayer.supabaseClient,
        exceptionMapper: apiLayer.exceptionMapper,
      );
  final ServiceContractRepository repository = ServiceContractRepositoryImpl(
    remote: resolvedDataSource,
  );
  final ContractService service = ContractService(
    repository: repository,
    supabase: apiLayer.supabaseClient,
    storage: storage,
    logger: logger,
  );
  return (
    repository: repository,
    provider: ServiceContractProvider(service: service, logger: logger),
    service: service,
  );
}

/// Wires the scheduling (availability + appointments) slice for EP-03-14.
///
/// Builds the [SchedulingRepository] and [SchedulingService] over the
/// [ApiLayer] and returns a ready [SchedulingProvider]. Mirrors
/// `registerServiceContractLayer`: all five scheduling RPCs are live, reads
/// are RLS participant-scoped (plan §7.1 Option B, zero new SQL) — the client
/// never writes scheduling tables.
({
  SchedulingRepository repository,
  SchedulingProvider provider,
  SchedulingService service,
})
registerSchedulingLayer(
  ApiLayer apiLayer, {
  SchedulingRemoteDataSource? dataSource,
  HivorrLogger? logger,
}) {
  final SchedulingRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseSchedulingRemoteDataSource(
        dio: apiLayer.dio,
        supabase: apiLayer.supabaseClient,
        exceptionMapper: apiLayer.exceptionMapper,
      );
  final SchedulingRepository repository = SchedulingRepositoryImpl(
    remote: resolvedDataSource,
  );
  final SchedulingService service = SchedulingService(
    repository: repository,
    logger: logger,
  );
  return (
    repository: repository,
    provider: SchedulingProvider(service: service, logger: logger),
    service: service,
  );
}

/// Wires the double-blind review slice for EP-03-12.
///
/// Builds the [ServiceReviewRepository] and [ServiceReviewService] over the
/// [ApiLayer] and returns a ready [ServiceReviewProvider]. Mirrors
/// `registerServiceContractLayer`: all three client-callable review RPCs are
/// live, reads are RLS participant-scoped (`get_mine`) or revealed-only
/// (`get_for_listing`), and reveal stays server-side — the client never
/// writes review tables and never calls `service_review_reveal_if_ready`.
({
  ServiceReviewRepository repository,
  ServiceReviewProvider provider,
  ServiceReviewService service,
})
registerServiceReviewLayer(
  ApiLayer apiLayer, {
  ServiceReviewRemoteDataSource? dataSource,
  HivorrLogger? logger,
}) {
  final ServiceReviewRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseServiceReviewRemoteDataSource(
        dio: apiLayer.dio,
        supabase: apiLayer.supabaseClient,
        exceptionMapper: apiLayer.exceptionMapper,
      );
  final ServiceReviewRepository repository = ServiceReviewRepositoryImpl(
    remote: resolvedDataSource,
  );
  final ServiceReviewService service = ServiceReviewService(
    repository: repository,
    logger: logger,
  );
  return (
    repository: repository,
    provider: ServiceReviewProvider(service: service, logger: logger),
    service: service,
  );
}

/// Wires the contract escrow release orchestration slice for EP-03-11.
///
/// Composes the [ContractService] verification half with the [EscrowService]
/// fund-movement half into a [ContractEscrowOrchestrator]. Additive only —
/// existing `registerEscrowLayer` / `registerServiceContractLayer` registrations
/// are untouched. The orchestrator is a sequencer only: verification and fund
/// movement stay server-authoritative (`AGENT.md` Rule 4); every release goes
/// through the `EscrowService` proxy seam and carries an idempotency key.
ContractEscrowOrchestrator registerContractEscrowLayer({
  required ContractService contractService,
  required EscrowService escrowService,
  HivorrLogger? logger,
}) {
  return ContractEscrowOrchestrator(
    contracts: contractService,
    escrows: escrowService,
    logger: logger,
  );
}

/// Wires the jobs/applications data slice for EP-04-01.
///
/// Builds the [JobRepository] and [JobService] over the [ApiLayer] and
/// returns a ready [JobProvider]. Mirrors `registerDisputeLayer`: all sixteen
/// authenticated RPCs are live, reads are RLS-scoped, and capability gates
/// stay server-side — the client never writes `jobs` tables.
({JobRepository repository, JobProvider provider}) registerJobsLayer(
  ApiLayer apiLayer,
) {
  final remote = SupabaseJobsRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = JobRepositoryImpl(remote: remote);
  final service = JobService(repository: repository);
  return (repository: repository, provider: JobProvider(service: service));
}

/// Wires the quotations/hires data slice for EP-04-02.
///
/// Builds the [HireRepository] and [HireService] over the [ApiLayer] and
/// returns a ready [HireProvider]. Mirrors `registerJobsLayer`: all eight
/// authenticated RPCs are live; `hire_accept` creates the linked
/// `service_contracts` row server-side — the client never writes hiring or
/// contract tables.
({HireRepository repository, HireProvider provider}) registerHiresLayer(
  ApiLayer apiLayer,
) {
  final remote = SupabaseHiresRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final repository = HireRepositoryImpl(remote: remote);
  final service = HireService(repository: repository);
  return (repository: repository, provider: HireProvider(service: service));
}

/// Wires the messaging data slice for EP-04-04.
///
/// Builds the [MessagingRepository] and [MessagingService] over the
/// [ApiLayer] and returns a ready [MessagingProvider]. Mirrors
/// `registerHiresLayer`: all four authenticated RPCs are live, reads are
/// RLS participant-scoped, payloads stay opaque — the client never writes
/// messaging tables and never handles plaintext outside `MessageCrypto`.
///
/// EP-03-13 collaborators are optional and backward-compatible: pass a
/// [Realtime] + [cache] + [outbox] + [isOnline] gate to enable live inserts,
/// warm-then-refresh windows, and durable offline sends. When absent the
/// provider keeps direct-send, poll-on-resume behavior.
({MessagingRepository repository, MessagingProvider provider})
registerMessagingLayer(
  ApiLayer apiLayer, {
  MessagingRealtimeDataSource? realtime,
  MessagingLocalDataSource? cache,
  StorageEngine? storageEngine,
  ActionQueue? outbox,
  bool Function()? isOnline,
  HivorrLogger? logger,
}) {
  final remote = SupabaseMessagingRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final MessagingRealtimeDataSource resolvedRealtime =
      realtime ?? SupabaseMessagingRealtimeDataSource(apiLayer.supabaseClient);
  final MessagingLocalDataSource? resolvedCache =
      cache ??
      (storageEngine == null
          ? null
          : MessagingLocalDataSource(store: LocalStore(storageEngine)));
  final repository = MessagingRepositoryImpl(remote: remote);
  final service = MessagingService(repository: repository, logger: logger);
  return (
    repository: repository,
    provider: MessagingProvider(
      service: service,
      logger: logger,
      realtime: resolvedRealtime,
      cache: resolvedCache,
      outbox: outbox,
      isOnline: isOnline,
    ),
  );
}

/// Wires the onboarding data slice for EP-02-18.
///
/// Builds the [OnboardingService] facade over the injected layers, the
/// authoritative [OnboardingRepository] (`entity_onboarding_status_*` RPCs)
/// and the [OnboardingProgressStore], then returns a ready [OnboardingProvider]
/// plus the store for widget-tree registration. Mirrors
/// `registerVerificationLayer`: the storage service is `SupabaseStorageService`
/// over the API-layer Dio (progress-aware uploads to `profile-avatars` /
/// `credential-documents`) with an injectable override for tests. Consumes the
/// existing [IdentityVerificationService] / [TradeVerificationService] facades
/// — no new transport (plan §5.2, §5.8).
///
/// The store is cache-only (server-authoritative completion): when
/// [storageEngine] is supplied the [HiveOnboardingProgressStore] backs it so
/// the resume position survives relaunch, degrading to in-memory otherwise.
({
  OnboardingService service,
  OnboardingProvider provider,
  OnboardingProgressStore store,
})
registerOnboardingLayer({
  required ApiLayer apiLayer,
  required EntityProvider entityProvider,
  required TaxonomyProvider taxonomyProvider,
  required IdentityVerificationService identityVerification,
  required TradeVerificationService tradeVerification,
  StorageService? storage,
  StorageEngine? storageEngine,
  OnboardingProgressStore? store,
  HivorrLogger? logger,
}) {
  final StorageService resolvedStorage =
      storage ??
      SupabaseStorageService(
        storageClient: apiLayer.supabaseClient.storage,
        dio: apiLayer.dio,
        tokenProvider: apiLayer.tokenProvider,
      );
  final OnboardingProgressStore resolvedStore =
      store ??
      (storageEngine != null
          ? HiveOnboardingProgressStore(store: LocalStore(storageEngine))
          : InMemoryOnboardingProgressStore());
  final onboardingRemote = SupabaseOnboardingRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final OnboardingRepository onboardingRepository = OnboardingRepositoryImpl(
    remote: onboardingRemote,
  );
  final OnboardingService service = OnboardingService(
    store: resolvedStore,
    entityRepository: entityProvider.repository,
    taxonomy: taxonomyProvider,
    identityVerification: identityVerification,
    tradeVerification: tradeVerification,
    storage: resolvedStorage,
    onboardingRepository: onboardingRepository,
    logger: logger,
  );
  return (
    service: service,
    provider: OnboardingProvider(service: service, logger: logger),
    store: resolvedStore,
  );
}
