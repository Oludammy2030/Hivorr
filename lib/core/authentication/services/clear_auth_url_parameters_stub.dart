/// No-op URL cleanup on non-web platforms.
///
/// Password-recovery callbacks only arrive in the browser address bar on Web;
/// there is nothing to clean up elsewhere.
void clearAuthUrlParameters() {}
