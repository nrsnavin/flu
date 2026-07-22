import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../models/user.dart';
import '../screens/home.dart';
import 'storage_keys.dart';

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

  // ── Manual login ──────────────────────────────────────────────────────

  void tryLogin(String email, String password) async {
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
        await _saveSession(token: newToken, user: u);
        user.value       = u;
        isLoggedIn.value = true;
        Get.offAll(() => Home());
      } else {
        Get.snackbar('Login Failed', 'Unexpected server response.',
            snackPosition: SnackPosition.BOTTOM);
      }
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
    } catch (e) {
      Get.snackbar('Login Failed', 'Something went wrong. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
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

  // Returns true if the request was accepted (backend always replies
  // generically), false on a network failure.
  Future<bool> requestOtp(String email) async {
    isRequestingOtp.value = true;
    try {
      await _dio.post(
        '/user/request-otp',
        data: {'email': email.trim()},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response != null
          ? 'Something went wrong. Please try again.'
          : 'Could not reach the server. Check your connection and try again.';
      Get.snackbar('Could not send code', msg, snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (_) {
      Get.snackbar('Could not send code', 'Something went wrong. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
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
        await _saveSession(token: newToken, user: u);
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

  Future<void> _saveSession({required String token, required User user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.token, token);
    await prefs.setString(StorageKeys.id,    user.id);
    await prefs.setString(StorageKeys.name,  user.name);
    await prefs.setString(StorageKeys.role,  user.role);
    await prefs.setBool(StorageKeys.isLoggedIn, true);
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.id);
    await prefs.remove(StorageKeys.name);
    await prefs.remove(StorageKeys.role);
    await prefs.setBool(StorageKeys.isLoggedIn, false);
  }
}
