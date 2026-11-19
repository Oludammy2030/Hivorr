/**
 * Payment provider boundary.
 *
 * The port is provider-agnostic. VFD adapters (`EP-02-041` to `EP-02-045`) live
 * beside this file once written confirmation and sandbox credentials exist.
 */
export {
  PAYMENT_PROVIDER_ERROR_CODES,
  PaymentProviderError,
  isPaymentProviderError,
} from "./payment-provider"
export type {
  AccountNameEnquiry,
  AccountNameEnquiryRequest,
  CollectionAccount,
  CollectionAccountRequest,
  DepositEvent,
  PaymentProvider,
  PaymentProviderErrorCode,
  PaymentStatus,
  PaymentStatusQuery,
  PayoutRequest,
  PayoutResult,
  ProviderOperationContext,
} from "./payment-provider"
export { FakePaymentProvider } from "./fake-payment-provider"
