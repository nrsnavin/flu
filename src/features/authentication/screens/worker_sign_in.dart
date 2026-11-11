import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../floor/screens/floor_page.dart';
import '../controllers/login_controller.dart';
import 'login.dart';

// ══════════════════════════════════════════════════════════════
//  SIGN IN AS EMPLOYEE — phone number and PIN
//
//  The employee door into the one app. Workers rarely have an email,
//  so they sign in with the phone number on their employee record and
//  a PIN the office sets (Employees → phone sign-in, on the web). The
//  session is the same one the staff form gives; the server marks it a
//  worker's, and AuthGate opens the employee screens for it.
//
//  Both ways in are open to everyone: phone and PIN here, or email
//  (a code, or a password) on the staff form, one tap away below.
//  Whichever is used, the server's answer decides where the person
//  lands — a worker's own login on the employee screens, an office
//  login on Home.
//
//  Shown two ways:
//    * from the welcome screen's "Sign in as employee" button, with a
//      back arrow;
//    * as the first screen itself on a phone marked shared ([kiosk]),
//      with the office sign-in one tap away below.
//
//  The rules match the web's phone sign-in (prod_web LoginPage.tsx), so
//  a number typed as +91 98765 43210 or 098765 43210 works here too.
// ══════════════════════════════════════════════════════════════

/// The 10-digit number from however it was typed; null when it is not
/// one. The same rule as the web and the server's normalisePhone.
String? phoneDigits(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 10) return d;
  if (d.length == 11 && d.startsWith('0')) return d.substring(1);
  if (d.length == 12 && d.startsWith('91')) return d.substring(2);
  return null;
}

class WorkerSignInPage extends StatefulWidget {
  /// The first screen of a shared phone, rather than a page opened from
  /// the welcome screen.
  final bool kiosk;
  const WorkerSignInPage({super.key, this.kiosk = false});

  @override
  State<WorkerSignInPage> createState() => _WorkerSignInPageState();
}

class _WorkerSignInPageState extends State<WorkerSignInPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  String? _serverError;

  LoginController get _c => LoginController.find;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);
    final error = await _c.tryWorkerLogin(phoneDigits(_phone.text)!, _pin.text.trim());
    if (!mounted || error == null) return;
    // A wrong PIN is typed again, not edited: clear it.
    _pin.clear();
    setState(() => _serverError = error);
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
          Expanded(
            flex: 3,
            child: SafeArea(
              child: Stack(children: [
                if (!widget.kiosk)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: () => Get.back(),
                    ),
                  ),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: ErpColors.accentBlue.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: Icon(Icons.badge_outlined,
                          size: 34, color: ErpColors.accentBlue),
                    ),
                    const SizedBox(height: 16),
                    const Text('ANU TAPES',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3)),
                    const SizedBox(height: 4),
                    Text(widget.kiosk ? 'Shared phone · Employee sign-in' : 'Employee sign-in',
                        style: TextStyle(
                            color: ErpColors.textOnDarkSub,
                            fontSize: 12,
                            letterSpacing: 0.8)),
                  ]),
                ),
              ]),
            ),
          ),
          Expanded(
            flex: 7,
            child: Container(
              decoration: BoxDecoration(
                color: ErpColors.bgBase,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: _formBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formBody() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign in as employee',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
              'Use the phone number on your employee record and the PIN '
              'the office gave you.',
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 26),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
              LengthLimitingTextInputFormatter(16),
            ],
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput(
              'Phone number',
              hint: '98765 43210',
              prefix: Icon(Icons.phone_iphone_rounded,
                  size: 18, color: ErpColors.textMuted),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your phone number';
              if (phoneDigits(v) == null) return 'Enter your 10-digit phone number';
              return null;
            },
            onFieldSubmitted: (_) => _pinFocus.requestFocus(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pin,
            focusNode: _pinFocus,
            keyboardType: TextInputType.number,
            obscureText: true,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: ErpTextStyles.fieldValue.copyWith(letterSpacing: 6),
            decoration: ErpDecorations.formInput(
              'PIN',
              hint: '••••',
              prefix: Icon(Icons.pin_outlined,
                  size: 18, color: ErpColors.textMuted),
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Enter your PIN';
              if (!RegExp(r'^\d{4,6}$').hasMatch(t)) return 'Your PIN is 4 to 6 digits';
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_serverError != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ErpColors.errorRed.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ErpColors.errorRed.withValues(alpha: 0.25)),
              ),
              child: Text(_serverError!,
                  style: TextStyle(
                      color: ErpColors.errorRed, fontSize: 12.5, height: 1.4)),
            ),
          ],
          const SizedBox(height: 28),
          Obx(() {
            final busy = _c.isLoading.value;
            return SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: busy ? null : _submit,
                child: busy
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
            );
          }),
          const SizedBox(height: 14),
          Text('Forgot your PIN? Ask the office to reset it.',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 12)),
          const SizedBox(height: 18),
          Divider(color: ErpColors.borderLight, height: 1),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => widget.kiosk
                  ? Get.to(() => const Login(backToEmployee: true))
                  : Get.off(() => const Login()),
              child: Text('Sign in with email instead',
                  style: TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          // A shared phone by the looms is where the floor supervisor
          // enters production too.
          if (widget.kiosk)
            Center(
              child: TextButton(
                onPressed: () => Get.to(() => const FloorPage()),
                child: Text('Floor entry with the shift PIN',
                    style: TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
