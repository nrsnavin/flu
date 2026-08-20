import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../models/user.dart';
import '../screens/home.dart';
import 'storage_keys.dart';

/// The outcome of asking for a sign-in code.
///
/// Three states rather than a bool, because each sends the person
/// somewhere different: on to the code screen, over to the password
/// screen, or back to the email field with a reason.
class OtpRequest {
  final bool sent;

  /// The server has no mail configured at all (503
  /// MAILER_NOT_CONFIGURED). Not a retry — this route is closed until
  /// somebody sets up SMTP.
  final bool mailerDown;

  /// Why it failed, in the server's own words where there were any.
  final String? message;

  const OtpRequest.sent()
      : sent = true, mailerDown = false, message = null;
  const OtpRequest.mailerDown()
      : sent = false, mailerDown = true, message = null;
  const OtpRequest.failed(this.message)
      : sent = false, mailerDown = false;
}

class LoginController extends GetxController {
  // Lazy registration so `buildActorPayload()` (and any other caller)
  // always gets a controller back, even if the user opened a deep
  // link / tile route that hasn't gone through the login screen yet.
  static LoginController get find => Get.isRegistered<LoginController>()
      ? Get.find<LoginController>()
      : Get.put(LoginController(), permanent: true);

  Rx<User>  user            = User(id: '', name: '', role: '').obs;
  RxBool    isLoading        = false.obs;
  RxBool    isLoggedIn       = false.obs;
  RxBool    isCheckingAuth   = true.obs;

  Dio get _dio => ApiClient.instance.dio;

  @override
  void onInit() {
    super.onInit();
    _handleAutoLogin();
  }

  // ── Auto-login on cold start ─────────────────────────────────────────────

  Future<void> _handleAutoLogin() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(StorageKeys.token) ?? '';
      if (storedToken.isEmpty) return;

      // The interceptor in ApiClient attaches the cookie automatically.
      final response = await _dio.get(
        '/user/getuser',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final u = response.data['user'];
        user.value = User(
          id:   u['_id']?.toString()       ?? prefs.getString(StorageKeys.id)   ?? '',
          name: (u['name'] ?? u['username'])?.toString()
                                            ?? prefs.getString(StorageKeys.name) ?? '',
          role: u['role']?.toString()       ?? prefs.getString(StorageKeys.role) ?? '',
        );
        isLoggedIn.value = true;
      } else {
        await _clearSession(prefs);
      }
    } catch (_) {
      // Network unavailable — restore from cache so the user isn't locked
      // out when the factory has no connectivity.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(StorageKeys.isLoggedIn) == true &&
          (prefs.getString(StorageKeys.token) ?? '').isNotEmpty) {
        user.value = User(
          id:   prefs.getString(StorageKeys.id)   ?? '',
          name: prefs.getString(StorageKeys.name) ?? '',
          role: prefs.getString(StorageKeys.role) ?? '',
        );
        isLoggedIn.value = true;
      }
    } finally {
      isCheckingAuth.value = false;
    }
  }

  // ── Password login ────────────────────────────────────────────────────
  //
  //  The fallback, and the reason it exists: email OTP is the front door,
  //  but it has a dependency the person signing in can neither see nor
  //  fix. When SMTP is down the door does not open for ANYBODY, and this
  //  endpoint is the way in — the same reasoning, and the same three
  //  routes to it, as the web login (prod_web LoginPage.tsx).
  //
  //  Returns true when the session was established; the caller keeps the
  //  form up on false.

  Future<bool> tryLogin(String email, String password) async {
    isLoading.value = true;
    try {
      final response = await _dio.post(
        '/user/login-user',
        // Trim the email — the backend does an exact-match lookup, so a
        // trailing space (common from keyboard autofill) would otherwise
        // cause a false 401. Casing is left as-typed to avoid breaking
        // accounts stored with mixed-case emails.
        data: {'email': email.trim(), 'password': password},
      );

      if (response.statusCode == 201) {
        final newToken = response.data['token'] ?? '';
        final u = User(
          id:   response.data['id']       ?? '',
          name: response.data['username'] ?? '',
          role: response.data['role']     ?? '',
        );
        await _saveSession(
          token: newToken,
          user: u,
          features: _parseFeatures(response.data['features']),
        );
        user.value       = u;
        isLoggedIn.value = true;
        Get.offAll(() => Home());
        return true;
      }
      Get.snackbar('Login Failed', 'Unexpected server response.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } on DioException catch (e) {
      // Distinguish "the server rejected the credentials" (there IS a
      // response) from "the request never reached the server" (no response
      // — e.g. Android blocking cleartext HTTP, no connectivity, wrong URL,
      // or a timeout). Previously both showed "check your credentials",
      // which hid real network failures behind a fake auth error.
      String title = 'Login Failed';
      String msg;
      if (e.response != null) {
        msg = e.response?.data is Map
            ? (e.response?.data['message']?.toString() ?? 'Invalid email or password')
            : 'Invalid email or password';
      } else {
        title = 'Cannot reach server';
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
          case DioExceptionType.sendTimeout:
            msg = 'The server took too long to respond. Check your connection and try again.';
            break;
          case DioExceptionType.connectionError:
          default:
            msg = 'Could not connect to the server. If this is a built app, the phone may be '
                'blocking plain-HTTP traffic, or the server is unreachable from this network.';
        }
      }
      Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (e) {
      Get.snackbar('Login Failed', 'Something went wrong. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Email-OTP login ──────────────────────────────────────────────────────
  //
  //  Primary sign-in: request a 6-digit code by email, then exchange it for
  //  the same JWT session /login-user issues. verifyOtp reuses the exact
  //  save-session + navigate path as tryLogin on success.
  final RxBool isRequestingOtp = false.obs;
  final RxBool isVerifyingOtp  = false.obs;

  /// What asking for a code actually did.
  ///
  /// This used to be a bool, and it was wrong twice over:
  ///
  ///   * `validateStatus: (s) => s < 500` made a 404 count as success, so
  ///     an email with no account advanced to the code screen and the
  ///     person sat typing codes at a door that was never going to open.
  ///     The server says "No account found for …" and nothing showed it.
  ///
  ///   * a server with no SMTP answers 503 MAILER_NOT_CONFIGURED. That is
  ///     a dead end for this route, not something to retry — and a bool
  ///     could only report it as "failed", leaving the person on a form
  ///     whose one button re-runs the thing that just failed.
  ///
  /// Three outcomes, because there are three different next steps.
  Future<OtpRequest> requestOtp(String email) async {
    isRequestingOtp.value = true;
    try {
      await _dio.post('/user/request-otp', data: {'email': email.trim()});
      return const OtpRequest.sent();
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map ? data['code']?.toString() : null;

      // No mailer on this box. Hand over the other door rather than
      // describing the locked one.
      if (code == 'MAILER_NOT_CONFIGURED') {
        return const OtpRequest.mailerDown();
      }

      if (e.response != null) {
        // The server's own words — "No account found for x@y.com. Check
        // the address, or ask an administrator to create your login." is
        // worth vastly more than "something went wrong".
        return OtpRequest.failed(
          (data is Map ? data['message']?.toString() : null) ??
              'Something went wrong. Please try again.',
        );
      }
      return const OtpRequest.failed(
          'Could not reach the server. Check your connection and try again.');
    } catch (_) {
      return const OtpRequest.failed(
          'Something went wrong. Please try again.');
    } finally {
      isRequestingOtp.value = false;
    }
  }

  // Verifies the code. On success saves the session and lands on Home,
  // exactly like tryLogin. Returns false so the caller can keep the code
  // screen up on failure.
  Future<bool> verifyOtp(String email, String otp) async {
    isVerifyingOtp.value = true;
    try {
      final response = await _dio.post(
        '/user/verify-otp',
        data: {'email': email.trim(), 'otp': otp.trim()},
      );

      if (response.statusCode == 201) {
        final newToken = response.data['token'] ?? '';
        final u = User(
          id:   response.data['id']       ?? '',
          name: response.data['username'] ?? '',
          role: response.data['role']     ?? '',
        );
        await _saveSession(
          token: newToken,
          user: u,
          features: _parseFeatures(response.data['features']),
        );
        user.value       = u;
        isLoggedIn.value = true;
        Get.offAll(() => Home());
        return true;
      }
      Get.snackbar('Sign-in failed', 'Unexpected server response.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } on DioException catch (e) {
      String title = 'Sign-in failed';
      String msg;
      if (e.response != null) {
        msg = e.response?.data is Map
            ? (e.response?.data['message']?.toString() ?? 'Invalid or expired code')
            : 'Invalid or expired code';
      } else {
        title = 'Cannot reach server';
        msg = 'Could not connect to the server. Check your connection and try again.';
      }
      Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (_) {
      Get.snackbar('Sign-in failed', 'Something went wrong. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isVerifyingOtp.value = false;
    }
  }

  // ── Forgot password ────────────────────────────────────────────────────
  //
  //  Asks the backend to email a reset link. The link opens the WEB reset
  //  page (erp.baluelastics.com/reset-password) — the phone doesn't handle
  //  the reset itself. The backend always returns a generic success, so we
  //  surface the same confirmation regardless of whether the email exists.
  //  Returns true when the request was accepted, false on a network error.
  final RxBool isSendingReset = false.obs;

  Future<bool> forgotPassword(String email) async {
    isSendingReset.value = true;
    try {
      await _dio.post(
        '/user/forgot-password',
        data: {'email': email.trim()},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response != null
          ? 'Something went wrong. Please try again.'
          : 'Could not reach the server. Check your connection and try again.';
      Get.snackbar('Reset failed', msg, snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (_) {
      Get.snackbar('Reset failed', 'Something went wrong. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSendingReset.value = false;
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    user.value       = User(id: '', name: '', role: '');
    isLoggedIn.value = false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> _saveSession({
    required String token,
    required User user,
    List<String> features = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.token, token);
    await prefs.setString(StorageKeys.id,    user.id);
    await prefs.setString(StorageKeys.name,  user.name);
    await prefs.setString(StorageKeys.role,  user.role);
    await prefs.setString(StorageKeys.features, features.join(','));
    await prefs.setBool(StorageKeys.isLoggedIn, true);
  }

  // Parse a login/verify response's `features` array into a string list.
  static List<String> _parseFeatures(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  // The current user's stored feature keys (empty => unrestricted).
  static Future<List<String>> currentFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.features) ?? '';
    if (raw.isEmpty) return const [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.id);
    await prefs.remove(StorageKeys.name);
    await prefs.remove(StorageKeys.role);
    await prefs.remove(StorageKeys.features);
    await prefs.setBool(StorageKeys.isLoggedIn, false);
  }
}
