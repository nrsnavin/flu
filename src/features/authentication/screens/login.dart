import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';

import '../../PurchaseOrder/services/theme.dart';
import 'forgot_password.dart';

// ══════════════════════════════════════════════════════════════
//  SIGNING IN WHEN THE CODE CANNOT COME
//
//  Email OTP is the front door and stays the front door. But it has a
//  dependency the person signing in can neither see nor fix — a
//  working mail server — and when that dependency is down the door
//  does not open for ANYBODY. /login-user has been sitting on the
//  backend the whole time for exactly this, and nothing on the phone
//  linked to it, so an SMTP outage locked the factory floor out of the
//  app with the fix already deployed and unreachable.
//
//  This mirrors the web login (prod_web LoginPage.tsx) deliberately,
//  down to which words appear where: two sign-in screens that disagree
//  about how to get in are two things to explain to a new operator.
//
//  The password screen is reachable three ways:
//
//    1. A link under the primary button. An advertised password route
//       arguably undoes the reason OTP is primary — but the two
//       automatic routes below both depend on the server behaving in a
//       particular way, and a way out that only opens when the system
//       is well enough to open it is not a way out.
//
//    2. The server says outright it cannot send. /request-otp answers
//       503 MAILER_NOT_CONFIGURED when the box has no SMTP settings —
//       a definite answer, so go straight there rather than making
//       somebody read an error and guess.
//
//    3. From the code screen, for when SMTP is configured but the send
//       fails. The server deliberately stays quiet about that (a
//       failure raised only for addresses that HAVE an account would
//       name them), so nothing can tell this screen — the link simply
//       sits there from the moment it opens.
//
//  The password FIELD is never on the first screen. Reaching it is a
//  deliberate second step.
// ══════════════════════════════════════════════════════════════

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

enum _Step { email, code, password }

class _LoginState extends State<Login> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey  = GlobalKey<FormState>();
  final _pwFormKey    = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _otpCtrl      = TextEditingController();
  final _pwCtrl       = TextEditingController();

  final _c = Get.find<LoginController>();

  _Step _step = _Step.email;
  int _resendIn = 0;
  Timer? _timer;

  /// Why we are on the password screen. The two routes there want
  /// different words: "this server cannot send codes" is a fact worth
  /// stating, and it also tells whoever runs the server where to look.
  /// "You said the code never came" is not worth stating back.
  bool _mailerDown = false;

  /// The last thing the server said, shown in place rather than as a
  /// snackbar that slides away while somebody is still reading it.
  String? _serverError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _pwCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendIn = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);

    final r = await _c.requestOtp(_emailCtrl.text.trim());
    if (!mounted) return;

    if (r.sent) {
      setState(() => _step = _Step.code);
      _startResendCountdown();
      return;
    }
    // A server with no mailer is a dead end for this route. Showing
    // "no email configured" and leaving somebody on a form whose only
    // button re-runs what just failed is a wall, not a message.
    if (r.mailerDown) {
      _goToPassword(becauseMailerIsDown: true);
      return;
    }
    setState(() => _serverError = r.message);
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    final r = await _c.requestOtp(_emailCtrl.text.trim());
    if (!mounted) return;
    if (r.sent) {
      _startResendCountdown();
    } else if (r.mailerDown) {
      _goToPassword(becauseMailerIsDown: true);
    } else {
      setState(() => _serverError = r.message);
    }
  }

  void _goToPassword({required bool becauseMailerIsDown}) {
    _timer?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _mailerDown  = becauseMailerIsDown;
      _serverError = null;
      _otpCtrl.clear();
      _step = _Step.password;
    });
  }

  /// Route to the password screen through the SAME validation as the
  /// primary button, so the address is checked once and cannot arrive
  /// there empty or malformed.
  void _usePasswordFromEmailStep() {
    if (!_emailFormKey.currentState!.validate()) return;
    _goToPassword(becauseMailerIsDown: false);
  }

  void _backToEmail() {
    _timer?.cancel();
    setState(() {
      _step = _Step.email;
      _serverError = null;
      _otpCtrl.clear();
      _pwCtrl.clear();
    });
  }

  void _verify() {
    if (!_codeFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);
    _c.verifyOtp(_emailCtrl.text.trim(), _otpCtrl.text.trim());
  }

  Future<void> _signInWithPassword() async {
    if (!_pwFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);
    await _c.tryLogin(_emailCtrl.text.trim(), _pwCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: ErpColors.navyDark,
      body: Column(
        children: [
          // ── Top brand strip ──────────────────────────────
          Expanded(
            flex: 3,
            child: SafeArea(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: ErpColors.accentBlue.withOpacity(0.4), width: 1.5),
                    ),
                    child: Icon(Icons.factory_rounded,
                        size: 36, color: ErpColors.accentBlue),
                  ),
                  const SizedBox(height: 16),
                  const Text('ANU TAPES',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3)),
                  const SizedBox(height: 4),
                  Text('Factory ERP System',
                      style: TextStyle(
                          color: ErpColors.textOnDarkSub, fontSize: 12, letterSpacing: 0.8)),
                ]),
              ),
            ),
          ),

          // ── Form card ────────────────────────────────────
          Expanded(
            flex: 7,
            child: Container(
              decoration: BoxDecoration(
                color: ErpColors.bgBase,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: switch (_step) {
                  _Step.email    => _emailStep(),
                  _Step.code     => _codeStep(),
                  _Step.password => _passwordStep(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: email ──────────────────────────────────────────
  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sign in',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        Text("Enter your email and we'll send you a sign-in code",
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 28),
        Form(
          key: _emailFormKey,
          child: TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput(
              'Email',
              hint: 'Enter your email address',
              prefix: Icon(Icons.mail_outline_rounded,
                  size: 18, color: ErpColors.textMuted),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
            onFieldSubmitted: (_) => _sendCode(),
          ),
        ),
        if (_serverError != null) ...[
          const SizedBox(height: 14),
          _errorBox(_serverError!),
        ],
        const SizedBox(height: 32),
        Obx(() => _primaryButton(
              label: 'SEND CODE',
              icon: Icons.send_rounded,
              loading: _c.isRequestingOtp.value,
              onPressed: _sendCode,
            )),

        // A text link under the primary button, not a password field:
        // the default action is still "send me a code".
        const SizedBox(height: 18),
        Divider(color: ErpColors.borderLight, height: 1),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _usePasswordFromEmailStep,
            child: Text('Sign in with a password instead',
                style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text('Anu Tapes Factory ERP  ·  v1.0',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        ),
      ],
    );
  }

  // ── Step 2b: password ──────────────────────────────────────
  Widget _passwordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.key_rounded, size: 24, color: ErpColors.accentBlue),
        ),
        const SizedBox(height: 14),
        Text('Sign in with your password',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        if (_mailerDown)
          // Worth stating plainly: it is not their email that is
          // broken, and it is not something they can fix by trying
          // again. It also tells whoever runs the server what to look
          // at.
          Text(
            "This server can't send sign-in codes at the moment — its "
            "email isn't set up. Use your password instead, and let your "
            "administrator know.",
            style: TextStyle(
                color: ErpColors.textSecondary, fontSize: 13, height: 1.4),
          )
        else
          Text.rich(TextSpan(
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'Signing in as '),
              TextSpan(
                  text: _emailCtrl.text.trim(),
                  style: TextStyle(
                      color: ErpColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              const TextSpan(text: '.'),
            ],
          )),
        const SizedBox(height: 26),
        Form(
          key: _pwFormKey,
          child: TextFormField(
            controller: _pwCtrl,
            obscureText: true,
            autofocus: true,
            // So a password manager can match the credential to the
            // account it belongs to.
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput(
              'Password',
              hint: 'Enter your password',
              prefix: Icon(Icons.lock_outline_rounded,
                  size: 18, color: ErpColors.textMuted),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) => _signInWithPassword(),
          ),
        ),
        if (_serverError != null) ...[
          const SizedBox(height: 14),
          _errorBox(_serverError!),
        ],
        const SizedBox(height: 24),
        Obx(() => _primaryButton(
              label: 'SIGN IN',
              icon: Icons.login_rounded,
              loading: _c.isLoading.value,
              onPressed: _signInWithPassword,
            )),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _backToEmail,
              icon: Icon(Icons.arrow_back_ios_new,
                  size: 13, color: ErpColors.accentBlue),
              label: Text('Back to sign-in',
                  style: TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),

            // Withheld when the server has told us it cannot send
            // email: a reset link arrives the same way a sign-in code
            // does. Offering it here would be a second dead end
            // dressed as a way out.
            if (!_mailerDown)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Get.to(() => const ForgotPasswordScreen()),
                child: Text('Forgot password?',
                    style: TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _errorBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ErpColors.errorRed.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.errorRed.withOpacity(0.25)),
        ),
        child: Text(text,
            style: TextStyle(
                color: ErpColors.errorRed, fontSize: 12.5, height: 1.4)),
      );

  // ── Step 2: code ───────────────────────────────────────────
  Widget _codeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter your code',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                  text: _emailCtrl.text.trim(),
                  style: TextStyle(
                      color: ErpColors.textPrimary, fontWeight: FontWeight.w700)),
              const TextSpan(text: '. It expires in 10 minutes.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Form(
          key: _codeFormKey,
          child: TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
                color: ErpColors.textPrimary),
            textAlign: TextAlign.center,
            decoration: ErpDecorations.formInput('6-digit code', hint: '••••••')
                .copyWith(counterText: ''),
            validator: (v) {
              if (v == null || v.trim().length != 6) return 'Enter the 6-digit code';
              return null;
            },
            onFieldSubmitted: (_) => _verify(),
          ),
        ),
        const SizedBox(height: 24),
        Obx(() => _primaryButton(
              label: 'VERIFY & SIGN IN',
              icon: Icons.login_rounded,
              loading: _c.isVerifyingOtp.value,
              onPressed: _verify,
            )),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _step = _Step.email;
                  _otpCtrl.clear();
                });
              },
              icon: Icon(Icons.arrow_back_ios_new, size: 13, color: ErpColors.accentBlue),
              label: Text('Change email',
                  style: TextStyle(
                      color: ErpColors.accentBlue, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _resendIn > 0 ? null : _resend,
              child: Text(
                _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code',
                style: TextStyle(
                    color: _resendIn > 0 ? ErpColors.textMuted : ErpColors.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),

        // Route 3. SMTP is configured but the send failed — the server
        // deliberately says nothing, because a failure raised only for
        // addresses that HAVE an account would name them. Nothing can
        // tell this screen, so the link sits here from the moment it
        // opens rather than appearing after some number of attempts.
        const SizedBox(height: 18),
        Divider(color: ErpColors.borderLight, height: 1),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _goToPassword(becauseMailerIsDown: false),
            child: Text("Code didn't arrive? Sign in with your password",
                style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ErpColors.accentBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                ],
              ),
      ),
    );
  }
}
