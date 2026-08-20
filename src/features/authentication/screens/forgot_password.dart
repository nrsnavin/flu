import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/login_controller.dart';

// ══════════════════════════════════════════════════════════════
//  FORGOT PASSWORD (mobile)
//
//  Collects the account email and calls /user/forgot-password. The
//  actual password change happens through the link the backend emails,
//  which opens the WEB reset page — so this screen ends at a "check
//  your email" confirmation rather than a new-password form.
// ══════════════════════════════════════════════════════════════

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _c = LoginController.find;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await _c.forgotPassword(_emailCtrl.text.trim());
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Reset password', style: ErpTextStyles.pageTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: _sent ? _confirmation() : _form(),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forgot your password?',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: ErpColors.textPrimary)),
        const SizedBox(height: 6),
        Text(
          "Enter your account email and we'll send you a link to reset your "
          'password. Open the link on any device to choose a new one.',
          style: TextStyle(color: ErpColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
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
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 28),
        Obx(() => SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _c.isSendingReset.value ? null : _submit,
                child: _c.isSendingReset.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('SEND RESET LINK',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0)),
              ),
            )),
      ],
    );
  }

  Widget _confirmation() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mark_email_read_outlined,
              size: 32, color: ErpColors.accentBlue),
        ),
        const SizedBox(height: 20),
        Text('Check your email',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: ErpColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          "If an account exists for that email, we've sent a link to reset your "
          'password. It expires in 30 minutes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ErpColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: ErpColors.accentBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text('BACK TO SIGN IN',
                style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
          ),
        ),
      ],
    );
  }
}
