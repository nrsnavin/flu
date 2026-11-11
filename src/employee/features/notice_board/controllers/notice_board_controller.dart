import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/emp_settings_controller.dart';
import '../../../core/safe_json.dart';
import '../../auth/controllers/emp_session.dart';

/// Loads active announcements for the worker's department from
/// `GET /announcement/active?dept=&lang=` — in the app's language where
/// the notice has been translated.
class EmpNoticeBoardController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final notices   = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final errorMsg  = Rxn<String>();

  String get _dept => EmpSession.find.user.value.department ?? '';

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value  = null;
    if (_dept.isEmpty) {
      // No department on the user → server would return every active
      // announcement, which is misleading on the worker portal.
      notices.clear();
      errorMsg.value =
          'No department on your account — ask your supervisor to link one.';
      isLoading.value = false;
      return;
    }
    try {
      final res = await _dio.get(
        '/announcement/active',
        // The app's language: the server answers with the notice in
        // Tamil or Hindi where it has one, English otherwise.
        queryParameters: {
          'dept': _dept,
          'lang': EmpSettingsController.find.locale.value.languageCode,
        },
      );
      notices.assignAll(
          SafeJson.asMapList(SafeJson.asMap(res.data)['data']));
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load notices';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
