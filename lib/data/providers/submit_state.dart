/// Lifecycle state of an identity-document submission (EP-02-10).
enum SubmitState {
  /// No submission in flight.
  idle,

  /// Storage upload + credential insert + queue in flight.
  submitting,

  /// The submission completed and a status refresh succeeded.
  success,

  /// The submission failed (see [VerificationProvider.submitError]).
  error,
}
