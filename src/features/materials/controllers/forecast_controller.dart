import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  ForecastController
//  Raw-material replenishment forecast. Mirrors the web Materials
//  Forecast — GET /api/v2/materials/replenishment-forecast.
// ══════════════════════════════════════════════════════════════
class ForecastController extends GetxController {
  final data     = Rxn<Map<String, dynamic>>();
  final loading  = false.obs;
  final errorMsg = Rxn<String>();

  final horizonDays  = 14.obs;
  final lookbackDays = 30;

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/materials',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  List<Map<String, dynamic>> get materials {
    final list = data.value?['materials'] as List? ?? [];
    return List<Map<String, dynamic>>.from(list);
  }

  Map<String, dynamic> get totals =>
      Map<String, dynamic>.from(data.value?['totals'] as Map? ?? {});

  Future<void> fetch() async {
    try {
      loading.value = true;
      errorMsg.value = null;
      final res = await _dio.get('/replenishment-forecast', queryParameters: {
        'horizonDays': horizonDays.value,
        'lookbackDays': lookbackDays,
      });
      data.value = Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ??
          'Failed to load forecast';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> setHorizon(int days) async {
    horizonDays.value = days;
    await fetch();
  }
}
