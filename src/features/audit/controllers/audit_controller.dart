import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  AuditController
//  Plant-wide fingerprint feed (Orders, Jobs, POs, DCs). Mirrors the
//  web Audit Trail — GET /api/v2/audit/recent (admin-gated).
// ══════════════════════════════════════════════════════════════
class AuditController extends GetxController {
  final entries  = <Map<String, dynamic>>[].obs;
  final loading  = false.obs;
  final errorMsg = Rxn<String>();

  // Cookie-attaching factory — /audit is behind the admin gate so a bare
  // Dio() 401s/403s.
  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/audit',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    try {
      loading.value = true;
      errorMsg.value = null;
      final res = await _dio.get('/recent', queryParameters: {'limit': 150});
      final List list = res.data['entries'] ?? [];
      entries.value = List<Map<String, dynamic>>.from(list);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load audit trail';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}
