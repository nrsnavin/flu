import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../models/covering.dart';

// ═════════════════════════════════════════════════════════════
//  COVERING LIST CONTROLLER (worker)
//
//  GET /covering/list?status=&search=&page=&limit=
// ═════════════════════════════════════════════════════════════
class EmpCoveringListController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final list      = <CoveringListItem>[].obs;
  final isLoading = false.obs;
  final hasMore   = true.obs;
  final errorMsg  = Rxn<String>();

  final statusFilter = 'open'.obs;
  final searchQuery  = ''.obs;

  int _page = 1;
  static const int _limit = 20;

  static const List<String> kStatuses = [
    'open', 'in_progress', 'completed', 'cancelled',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchList(reset: true);
  }

  Future<void> fetchList({bool reset = false}) async {
    if (isLoading.value) return;
    if (reset) {
      _page = 1;
      list.clear();
      hasMore.value = true;
      errorMsg.value = null;
    }
    if (!hasMore.value) return;

    isLoading.value = true;
    try {
      final res = await _dio.get('/covering/list', queryParameters: {
        'status': statusFilter.value,
        'search': searchQuery.value,
        'page':   _page,
        'limit':  _limit,
      });
      final body = SafeJson.asMap(res.data);
      final raw  = SafeJson.asMapList(body['data']);
      final pag  = SafeJson.asMap(body['pagination']);

      list.addAll(raw.map(CoveringListItem.fromJson));
      hasMore.value = SafeJson.asBool(pag['hasMore']);
      _page++;
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load coverings';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void setStatus(String s) {
    if (statusFilter.value == s) return;
    statusFilter.value = s;
    fetchList(reset: true);
  }

  void setSearch(String q) {
    searchQuery.value = q;
    fetchList(reset: true);
  }

  int get inProgressCount =>
      list.where((c) => c.status == 'in_progress').length;
  int get completedCount =>
      list.where((c) => c.status == 'completed').length;
}
