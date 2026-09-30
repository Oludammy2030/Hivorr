import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/entry/entry_query.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_colors.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// Email + password sign-in (auth flows §7 of the correction plan).
///
/// Pixel-matched to the `log in.png` reference: a royal-blue page with a
/// centered split card — brand panel (logo, headline, sub-copy, stats) on the
/// left, white sign-in form (`Welcome back 👋`) on the right. Narrow screens
/// stack the same two sections vertically inside the same rounded card.
///
/// Thin UI over [AuthProvider.signIn]: validates locally, calls the service
/// once, and routes to the preserved `?next=` destination (or home — the
/// RouteGuard then applies the onboarding resume gate) on success. When the
/// identity exists but its email is not verified yet (gotrue
/// `email_not_confirmed`, e.g. an abandoned registration), the visitor is sent
/// to the verification gate in resume mode, which issues a fresh code and then
/// continues to onboarding — never creating a duplicate account. Errors are
/// surfaced as the safe [ApiException.message]. No business logic here.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _submitting = false;
  String? _localError;

  static const Color _pageBlue = AppColors.brandPrimary;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String? error = _localError ?? auth.lastError?.message;
    // Mobile-only light page (<600px) matching the reference; desktop keeps
    // the royal-blue page 100% untouched.
    final bool isMobileScaffold = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor:
          isMobileScaffold ? const Color(0xFFF7F7F4) : _pageBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobileScaffold ? 16 : 24),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 900;
                // Mobile reference (<600px): form first above the fold, slim
                // marketing below, footer at the bottom. Tablet (600-899)
                // and desktop (>=900) keep their existing layouts untouched.
                if (constraints.maxWidth < 600) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const _MobileLogo(),
                          const SizedBox(height: 20),
                          _FormPanel(
                            email: _email,
                            password: _password,
                            submitting: _submitting,
                            error: error,
                            compact: true,
                            isMobile: true,
                            onChanged: () =>
                                setState(() => _localError = null),
                            onSubmit: _submit,
                            onForgotPassword: () => context.go(
                              _target(RoutePaths.forgotPassword),
                            ),
                            onCreateAccount: () =>
                                context.go(_target(RoutePaths.signup)),
                          ),
                          const SizedBox(height: 28),
                          const _MobileMarketing(),
                          const SizedBox(height: 24),
                          _MobileFooter(
                            submitting: _submitting,
                            onCreateAccount: () =>
                                context.go(_target(RoutePaths.signup)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1020),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 48,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: wide
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                const Expanded(child: _BrandPanel()),
                                Expanded(
                                  child: _FormPanel(
                                    email: _email,
                                    password: _password,
                                    submitting: _submitting,
                                    error: error,
                                    onChanged: () => setState(
                                      () => _localError = null,
                                    ),
                                    onSubmit: _submit,
                                    onForgotPassword: () => context.go(
                                      _target(RoutePaths.forgotPassword),
                                    ),
                                    onCreateAccount: () => context.go(
                                      _target(RoutePaths.signup),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const _BrandPanel(compact: true),
                              _FormPanel(
                                email: _email,
                                password: _password,
                                submitting: _submitting,
                                error: error,
                                compact: true,
                                onChanged: () =>
                                    setState(() => _localError = null),
                                onSubmit: _submit,
                                onForgotPassword: () => context.go(
                                  _target(RoutePaths.forgotPassword),
                                ),
                                onCreateAccount: () =>
                                    context.go(_target(RoutePaths.signup)),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final String email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _localError = 'Enter your email and password.');
      return;
    }
    setState(() {
      _submitting = true;
      _localError = null;
    });
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.signIn(AuthCredentials(email: email, password: _password.text));
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (auth.isSignedIn) {
      context.go(_target(_afterSignIn()));
      return;
    }
    if (auth.lastErrorCode == 'email_not_confirmed' ||
        auth.lastErrorCode == 'email_not_verified') {
      context.go(_verificationTarget(email));
    }
  }

  String _afterSignIn() {
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    if (next != null && next.isNotEmpty) {
      return next;
    }
    return RoutePaths.home;
  }

  /// Routes an unverified identity to the verification gate in resume mode.
  ///
  /// The gate will issue a fresh code on entry; verifying it confirms the email
  /// and continues to onboarding. No session exists yet, so nothing is lost by
  /// leaving login.
  String _verificationTarget(String email) {
    final String encodedEmail = Uri.encodeQueryComponent(email);
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    final String nextParam = (next == null || next.isEmpty)
        ? ''
        : '&next=${Uri.encodeQueryComponent(next)}';
    return '${RoutePaths.authConfirmation}?email=$encodedEmail'
        '&mode=${RoutePaths.authVerificationResumeMode}$nextParam';
  }

  /// Carries the preserved `?next=` across auth routes.
  String _target(String route) {
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));
    if (next == null || next.isEmpty) {
      return route;
    }
    return '$route?next=$next';
  }
}

/// Left-hand brand panel from the reference: logo lockup, headline,
/// supporting copy and the three proof stats.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double pad = compact ? 24 : 48;
    return Container(
      color: AppColors.brandPrimary,
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Hivorr',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 28 : 72),
          Text(
            "Africa's #1 Workforce Marketplace",
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 26 : 34,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Join 50,000+ professionals and employers building Africa's future together.",
            style: TextStyle(
              color: Color(0xD6FFFFFF),
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          SizedBox(height: compact ? 28 : 72),
          const Wrap(
            spacing: 28,
            runSpacing: 16,
            children: <Widget>[
              _Stat(value: '52K+', label: 'Professionals'),
              _Stat(value: '1.2K', label: 'Companies'),
              _Stat(value: r'$12M+', label: 'Earned'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Centered Hivorr lockup for the mobile reference (<600px only).
class _MobileLogo extends StatelessWidget {
  const _MobileLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.flash_on_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Hivorr',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Slim light-theme marketing block below the mobile form (reference order:
/// form first above the fold, marketplace + stats below, footer last).
class _MobileMarketing extends StatelessWidget {
  const _MobileMarketing();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          "Africa's #1 Workforce Marketplace",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Join 50,000+ professionals and employers building Africa's future together.",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.55,
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(child: _MobileStat(value: '52K+', label: 'Professionals')),
            Expanded(child: _MobileStat(value: '1.2K', label: 'Companies')),
            Expanded(child: _MobileStat(value: r'$12M+', label: 'Earned')),
          ],
        ),
      ],
    );
  }
}

class _MobileStat extends StatelessWidget {
  const _MobileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

/// Clean footer below the mobile marketing block (reference position).
class _MobileFooter extends StatelessWidget {
  const _MobileFooter({
    required this.submitting,
    required this.onCreateAccount,
  });

  final bool submitting;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        const Text(
          'New to Hivorr? ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
        ),
        TextButton(
          onPressed: submitting ? null : onCreateAccount,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppColors.brandPrimary,
          ),
          child: const Text(
            'Create account',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Right-hand white sign-in form from the reference.
class _FormPanel extends StatefulWidget {
  const _FormPanel({
    required this.email,
    required this.password,
    required this.submitting,
    required this.error,
    required this.onChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onCreateAccount,
    this.compact = false,
    this.isMobile = false,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool submitting;
  final String? error;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;
  final bool compact;

  /// When true (<600px reference), renders the tight above-the-fold mobile
  /// variant: zero outer padding (parent owns it), bordered white inputs,
  /// password visibility toggle, underlined forgot link, no inner footer
  /// (footer lives below the marketing block). Desktop/tablet untouched.
  final bool isMobile;

  @override
  State<_FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends State<_FormPanel> {
  bool _obscure = true;

  static const Color _ink = AppColors.textPrimary;
  static const Color _muted = AppColors.textSecondary;
  static const Color _fieldFill = Color(0xFFF2F4F7);
  static const Color _hint = AppColors.textMuted;

  InputBorder get _border => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );

  InputBorder get _mobileBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
  );

  @override
  Widget build(BuildContext context) {
    final bool isMobile = widget.isMobile;
    final bool compact = widget.compact;
    // Parent owns padding on mobile so the whole form fits above the fold.
    if (isMobile) {
      return _buildBody(context);
    }
    final double horizontalPad = compact ? 24 : 48;
    final double verticalPad = compact ? 32 : 52;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final bool isMobile = widget.isMobile;
    final bool compact = widget.compact;
    final TextEditingController email = widget.email;
    final TextEditingController password = widget.password;
    final bool submitting = widget.submitting;
    final String? error = widget.error;
    final VoidCallback onChanged = widget.onChanged;
    final VoidCallback onSubmit = widget.onSubmit;
    final VoidCallback onForgotPassword = widget.onForgotPassword;
    final VoidCallback onCreateAccount = widget.onCreateAccount;
    // Tight mobile rhythm so logo + full form fits above the fold.
    final double titleGap = isMobile ? 24 : 30;
    final double fieldGap = isMobile ? 16 : 20;
    final double forgotGap = isMobile ? 8 : 10;
    final double buttonGap = isMobile ? 12 : 14;
    final InputBorder emailBorder = isMobile ? _mobileBorder : _border;
    final InputBorder emailFocused = isMobile
        ? _mobileBorder.copyWith(
            borderSide: const BorderSide(
              color: AppColors.brandPrimary,
              width: 1.5,
            ),
          )
        : _border;
    final InputBorder passBorder = isMobile ? _mobileBorder : _border;
    final InputBorder passFocused = isMobile
        ? _mobileBorder.copyWith(
            borderSide: const BorderSide(
              color: AppColors.brandPrimary,
              width: 1.5,
            ),
          )
        : _border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Welcome back \u{1F44B}',
          style: TextStyle(
            color: _ink,
            fontSize: compact ? 26 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to your account',
          style: TextStyle(color: _muted, fontSize: 15),
        ),
        SizedBox(height: titleGap),
        const Text(
          'Email',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !submitting,
          onChanged: (_) => onChanged(),
          style: const TextStyle(color: _ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: const TextStyle(color: _hint, fontSize: 15),
            filled: true,
            fillColor: isMobile ? Colors.white : _fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: emailBorder,
            enabledBorder: emailBorder,
            focusedBorder: emailFocused,
            disabledBorder: emailBorder,
          ),
        ),
        SizedBox(height: fieldGap),
        const Text(
          'Password',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: password,
          obscureText: isMobile ? _obscure : true,
          textInputAction: TextInputAction.done,
          enabled: !submitting,
          onChanged: (_) => onChanged(),
          onSubmitted: (_) {
            if (!submitting) {
              onSubmit();
            }
          },
          style: const TextStyle(color: _ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            hintStyle: const TextStyle(color: _hint, fontSize: 15),
            filled: true,
            fillColor: isMobile ? Colors.white : _fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: passBorder,
            enabledBorder: passBorder,
            focusedBorder: passFocused,
            disabledBorder: passBorder,
            // Reference visibility toggle — mobile only, desktop untouched.
            suffixIcon: isMobile
                ? IconButton(
                    tooltip:
                        _obscure ? 'Show password' : 'Hide password',
                    onPressed: submitting
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: _muted,
                    ),
                  )
                : null,
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            error,
            style: const TextStyle(
              color: AppColors.lightError,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
        SizedBox(height: forgotGap),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: submitting ? null : onForgotPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.brandPrimary,
            ),
            child: Text(
              'Forgot password?',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                decoration:
                    isMobile ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
        SizedBox(height: buttonGap),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: submitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.brandPrimary.withValues(
                alpha: 0.7,
              ),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Sign In'),
          ),
        ),
        // Mobile footer lives below the marketing block (reference order),
        // so omit it inside the form. Tablet/desktop keep it inline.
        if (!isMobile) ...<Widget>[
          const SizedBox(height: 26),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text(
                'New to Hivorr? ',
                style: TextStyle(color: _muted, fontSize: 14.5),
              ),
              TextButton(
                onPressed: submitting ? null : onCreateAccount,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.brandPrimary,
                ),
                child: const Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
