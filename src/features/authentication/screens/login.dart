import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';

import '../../PurchaseOrder/services/theme.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Use find — LoginController is already registered in main.dart initialBinding
  final _loginController = Get.find<LoginController>();

  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
                    child: const Icon(Icons.factory_rounded,
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
                  const Text('Factory ERP System',
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
              decoration: const BoxDecoration(
                color: ErpColors.bgBase,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: ErpColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Sign in to access your ERP dashboard',
                        style: TextStyle(
                            color: ErpColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 28),

                    Form(
                      key: _formKey,
                      child: Column(children: [
                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: ErpTextStyles.fieldValue,
                          decoration: ErpDecorations.formInput(
                            'Email / Username',
                            hint: 'Enter your email address',
                            prefix: const Icon(Icons.person_outline_rounded,
                                size: 18, color: ErpColors.textMuted),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password with visibility toggle
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          style: ErpTextStyles.fieldValue,
                          decoration: ErpDecorations.formInput(
                            'Password',
                            hint: 'Enter your password',
                            prefix: const Icon(Icons.lock_outline_rounded,
                                size: 18, color: ErpColors.textMuted),
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: ErpColors.textMuted,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 32),

                        // Submit button — reactive to loading state
                        Obx(() => SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ErpColors.accentBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _loginController.isLoading.value ? null : _submit,
                            child: _loginController.isLoading.value
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 10),
                                      Text('SIGN IN',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2)),
                                    ],
                                  ),
                          ),
                        ))
                      ]),
                    ),

                    const SizedBox(height: 28),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Text('Anu Tapes Factory ERP  ·  v1.0',
                          style: TextStyle(color: ErpColors.textMuted, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _loginController.tryLogin(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
    }
  }
}
