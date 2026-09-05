import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Thrown when an escrow write action is requested while the Edge Function
/// proxy seam is disabled (EP-02-14 §5.2).
///
/// Deliberately a distinct [ApiException] subclass (`kind: forbidden`) so the
/// UI can render the "escrow actions via support team" guidance panel instead
/// of a generic forbidden error. The message must never be a silent no-op —
/// callers always surface the support-team guidance.
class EscrowWriteUnavailableException extends ApiException {
  const EscrowWriteUnavailableException()
      : super(
          kind: ApiExceptionKind.forbidden,
          message:
              'Escrow actions are not available yet — releases are handled by '
              'our support team.',
        );
}