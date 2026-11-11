import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/authentication/controllers/login_controller.dart';
import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../models/employee_user.dart';
import 'storage_keys.dart';

/// Who the employee screens are for: the signed-in login and the
/// employee record it is linked to.
///
/// It does not sign anybody in. Signing in and out belongs to the admin
/// app's LoginController — the staff form, or "Sign in as employee"
/// with phone and PIN — and both sides share its one session. This
/// reads /user/me for the linked employee (whose id every employee
/// screen asks the server about) and hands sign-out back to it.
///
/// It was the employee app's LoginController. Renamed, not just moved:
/// GetX finds a controller by its class NAME, and the admin app has a
/// LoginController too — two of them would have answered for each other.
class EmpSession extends GetxController {
  static EmpSession get find => Get.isRegistered<EmpSession>()
      ? Get.find<EmpSession>()
      : Get.put(EmpSession(), permanent: true);

  Dio get _dio => ApiClient.instance.dio;

  final user      = EmployeeUser.empty.obs;
  final isLoading = false.obs;

  /// Set when /user/me could not be read and nothing was cached either:
  /// the home screen says so instead of showing an empty name.
  final loadError = RxnString();

  @override
  void onInit() {
    super.onInit();
    // The server no longer accepts this session: sign out here too.
    ApiClient.onSessionEnded = () {
      if (LoginController.find.isLoggedIn.value) logout();
    };
  }

  /// Read the login and its employee. Called when an employee screen
  /// opens; cheap enough to call again to refresh.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // A different login from the one last read (somebody signed out by
    // another route — the lock, the shared-phone timer — and somebody
    // else in): never draw the last person's card over this one's.
    if (user.value.userId != LoginController.find.user.value.id) {
      user.value = EmployeeUser.empty;
      _restoreFromCache(prefs);
    }
    isLoading.value = true;
    loadError.value = null;
    try {
      final res = await _dio.get('/user/me');
      final u = EmployeeUser.fromMe(
          SafeJson.asMap(SafeJson.asMap(res.data)['user']));
      user.value = u;
      await _persist(prefs, u);
    } on DioException catch (e) {
      // A 401 is handled by ApiClient.onSessionEnded (signs out).
      // Anything else — offline, a slow server — keeps what was cached,
      // so a worker with no signal still sees their own home screen.
      if (e.response?.statusCode != 401 && user.value.userId.isEmpty) {
        loadError.value = e.response == null
            ? 'Could not reach the server. Check your connection.'
            : (SafeJson.asStringOrNull(
                    SafeJson.asMap(e.response?.data)['message']) ??
                'Could not load your details.');
      }
    } catch (_) {
      if (user.value.userId.isEmpty) {
        loadError.value = 'Could not load your details.';
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign out of the app — the same sign-out the office screens use,
  /// which ends the session on the server too — and go back to the first
  /// screen, which is then the sign-in screen. Without that last step a
  /// page opened on top (the profile, say) stayed showing after sign-out.
  Future<void> logout() async {
    await LoginController.find.logout();
    await forget();
    Get.until((route) => route.isFirst);
  }

  /// Drop the cached employee card (sign-out, or a different login).
  Future<void> forget() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in EmpStorageKeys.all) {
      await prefs.remove(k);
    }
    user.value = EmployeeUser.empty;
    loadError.value = null;
  }

  void _restoreFromCache(SharedPreferences prefs) {
    final id = prefs.getString(EmpStorageKeys.userId) ?? '';
    // Only this login's card: a phone shared by two people must not draw
    // the last one's name over the next one's session.
    if (id.isEmpty || id != LoginController.find.user.value.id) return;
    user.value = EmployeeUser(
      userId:       id,
      name:         prefs.getString(EmpStorageKeys.userName)  ?? '',
      email:        prefs.getString(EmpStorageKeys.userEmail) ?? '',
      role:         prefs.getString(EmpStorageKeys.userRole)  ?? '',
      employeeId:   prefs.getString(EmpStorageKeys.employeeId),
      department:   prefs.getString(EmpStorageKeys.employeeDept),
      employeeRole: prefs.getString(EmpStorageKeys.employeeRole),
      phoneNumber:  prefs.getString(EmpStorageKeys.employeePhone),
      hourlyRate:   prefs.getDouble(EmpStorageKeys.employeeRate),
    );
  }

  Future<void> _persist(SharedPreferences prefs, EmployeeUser u) async {
    await prefs.setString(EmpStorageKeys.userId,    u.userId);
    await prefs.setString(EmpStorageKeys.userName,  u.name);
    await prefs.setString(EmpStorageKeys.userEmail, u.email);
    await prefs.setString(EmpStorageKeys.userRole,  u.role);
    Future<void> put(String k, String? v) =>
        v == null ? prefs.remove(k) : prefs.setString(k, v);
    await put(EmpStorageKeys.employeeId,    u.employeeId);
    await put(EmpStorageKeys.employeeDept,  u.department);
    await put(EmpStorageKeys.employeeRole,  u.employeeRole);
    await put(EmpStorageKeys.employeePhone, u.phoneNumber);
    if (u.hourlyRate == null) {
      await prefs.remove(EmpStorageKeys.employeeRate);
    } else {
      await prefs.setDouble(EmpStorageKeys.employeeRate, u.hourlyRate!);
    }
  }
}
