/// Typed, namespaced translation keys for compile-time safety and IDE
/// autocomplete.
///
/// Every user-facing string in EP-02+ is referenced through one of these
/// constants — never as a raw string literal in a widget. EP-02+ extends this
/// set as new features land; every added constant must have a corresponding
/// entry in `assets/translations/{code}.json`.
class TranslationKeys {
  TranslationKeys._();

  // Common -----------------------------------------------------------------
  static const String commonOk = 'common.ok';
  static const String commonCancel = 'common.cancel';
  static const String commonSave = 'common.save';
  static const String commonDelete = 'common.delete';
  static const String commonEdit = 'common.edit';
  static const String commonDone = 'common.done';
  static const String commonRetry = 'common.retry';
  static const String commonLoading = 'common.loading';
  static const String commonError = 'common.error';
  static const String commonSuccess = 'common.success';
  static const String commonWarning = 'common.warning';
  static const String commonNoData = 'common.noData';
  static const String commonSearch = 'common.search';
  static const String commonClose = 'common.close';
  static const String commonBack = 'common.back';
  static const String commonNext = 'common.next';
  static const String commonYes = 'common.yes';
  static const String commonNo = 'common.no';
  static const String commonItemCount = 'common.itemCount';

  // Auth --------------------------------------------------------------------
  static const String authLoginTitle = 'auth.loginTitle';
  static const String authSignupTitle = 'auth.signupTitle';
  static const String authEmail = 'auth.email';
  static const String authPassword = 'auth.password';
  static const String authForgotPassword = 'auth.forgotPassword';
  static const String authLoginButton = 'auth.loginButton';
  static const String authSignupButton = 'auth.signupButton';
  static const String authLogoutButton = 'auth.logoutButton';
  static const String authNoAccount = 'auth.noAccount';
  static const String authHasAccount = 'auth.hasAccount';

  // Errors ------------------------------------------------------------------
  static const String errorGeneric = 'errors.generic';
  static const String errorNetwork = 'errors.network';
  static const String errorTimeout = 'errors.timeout';
  static const String errorUnauthorized = 'errors.unauthorized';
  static const String errorNotFound = 'errors.notFound';
  static const String errorServer = 'errors.server';

  // Validation --------------------------------------------------------------
  static const String validationRequired = 'validation.required';
  static const String validationEmail = 'validation.email';
  static const String validationPhone = 'validation.phone';
  static const String validationMinLength = 'validation.minLength';
  static const String validationMaxLength = 'validation.maxLength';
  static const String validationPasswordStrength =
      'validation.passwordStrength';

  // App ---------------------------------------------------------------------
  static const String appTitle = 'app.title';
  static const String appTagline = 'app.tagline';
}
