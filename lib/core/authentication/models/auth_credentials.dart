/// Email + password pair used for authentication.
///
/// The raw password is held only for the duration of a sign-in/sign-up call
/// and is never persisted or logged (AGENT.md, EP-01-09 §12).
class AuthCredentials {
  const AuthCredentials({required this.email, required this.password});

  final String email;
  final String password;
}
