import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/erp_theme.dart';
import '../controllers/login_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _showPass  = false.obs;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = LoginController.find;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Brand block ─────────────────────────────────
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: ErpColors.navyDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.engineering_outlined,
                      color: Colors.white, size: 38),
                ),
                const SizedBox(height: 18),
                const Text('Worker Portal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary,
                      letterSpacing: -0.4,
                    )),
                const SizedBox(height: 4),
                const Text('Sign in to log production, view shifts and payroll.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 12,
                    )),
                const SizedBox(height: 32),

                // ── Login card ─────────────────────────────────
                Container(
                  decoration: ErpDecorations.card,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        style: const TextStyle(fontSize: 14),
                        decoration: ErpDecorations.formInput(
                          'Email',
                          prefix: const Icon(Icons.alternate_email,
                              size: 18, color: ErpColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(() => TextField(
                            controller: _passCtrl,
                            obscureText: !_showPass.value,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(c),
                            style: const TextStyle(fontSize: 14),
                            decoration: ErpDecorations.formInput(
                              'Password',
                              prefix: const Icon(Icons.lock_outline,
                                  size: 18, color: ErpColors.textMuted),
                              suffix: IconButton(
                                icon: Icon(
                                  _showPass.value
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: ErpColors.textMuted,
                                ),
                                onPressed: () =>
                                    _showPass.value = !_showPass.value,
                              ),
                            ),
                          )),
                      const SizedBox(height: 18),
                      Obx(() => SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: c.isLoading.value
                                  ? null
                                  : () => _submit(c),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ErpColors.accentBlue,
                                disabledBackgroundColor:
                                    ErpColors.accentBlue.withOpacity(0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              child: c.isLoading.value
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Sign In',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Trouble signing in? Ask your supervisor to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(LoginController c) {
    c.tryLogin(_emailCtrl.text, _passCtrl.text);
  }
}
