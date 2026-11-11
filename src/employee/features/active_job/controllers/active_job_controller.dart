import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../auth/controllers/emp_session.dart';

/// Loads ALL of the worker's currently OPEN shifts.
///
/// A worker can be running multiple machines / job orders at the
/// same time (e.g. weaving on M-12 and M-18 during the DAY shift).
/// The Worker Portal lists them; each is deep-populated with
/// machine + orderRunning + elastics so the detail screen needs
/// zero further round trips.
///
/// Backed by `GET /shift/active-jobs/:empId` which returns
/// `{ success, count, shifts: [...] }`.
class EmpActiveJobController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final shifts    = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final errorMsg  = Rxn<String>();

  String get _empId => EmpSession.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    if (_empId.isEmpty) {
      errorMsg.value = 'No employee record linked.';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get('/shift/active-jobs/$_empId');
      shifts.assignAll(
          SafeJson.asMapList(SafeJson.asMap(res.data)['shifts']));
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load active jobs';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Helpers used elsewhere (e.g. Machine Issue form) to pick from
  /// the currently-running machines without re-fetching.
  List<Map<String, dynamic>> get activeMachines {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final s in shifts) {
      final m = SafeJson.asMapOrNull(s['machine']);
      if (m == null) continue;
      final id = SafeJson.asString(m['_id']);
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(m);
    }
    return out;
  }
}
