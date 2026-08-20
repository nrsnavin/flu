import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';

import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  LOGIN — email-OTP (two step)
//
//  Step 1: enter email → request a 6-digit code.
//  Step 2: enter the code → verify → Home.
//  Password login is retired from the UI (the /login-user endpoint
//  stays server-side as an emergency fallback).
// ══════════════════════════════════════════════════════════════

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

enum _Step { email, code }

class _LoginState extends State<Login> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey  = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _otpCtrl      = TextEditingController();

  final _c = Get.find<LoginController>();

  _Step _step = _Step.email;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
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
    final ok = await _c.requestOtp(_emailCtrl.text.trim());
    if (ok && mounted) {
      setState(() => _step = _Step.code);
      _startResendCountdown();
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    final ok = await _c.requestOtp(_emailCtrl.text.trim());
    if (ok && mounted) _startResendCountdown();
  }

  void _verify() {
    if (!_codeFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _c.verifyOtp(_emailCtrl.text.trim(), _otpCtrl.text.trim());
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
                child: _step == _Step.email ? _emailStep() : _codeStep(),
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
        const SizedBox(height: 32),
        Obx(() => _primaryButton(
              label: 'SEND CODE',
              icon: Icons.send_rounded,
              loading: _c.isRequestingOtp.value,
              onPressed: _sendCode,
            )),
        const SizedBox(height: 28),
        Center(
          child: Text('Anu Tapes Factory ERP  ·  v1.0',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        ),
      ],
    );
  }

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
