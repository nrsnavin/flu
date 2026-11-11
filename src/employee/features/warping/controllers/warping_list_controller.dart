import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../models/warping.dart';

// ═════════════════════════════════════════════════════════════
//  WARPING LIST CONTROLLER
//
//  GET /warping/list?status=&search=&page=&limit=
//  Backend prod PR #17 opened this endpoint to workers (read-only).
// ═════════════════════════════════════════════════════════════
class EmpWarpingListController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final list      = <WarpingListItem>[].obs;
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
      final res = await _dio.get('/warping/list', queryParameters: {
        'status': statusFilter.value,
        'search': searchQuery.value,
        'page':   _page,
        'limit':  _limit,
      });
      final body = SafeJson.asMap(res.data);
      final raw  = SafeJson.asMapList(body['data']);
      final pag  = SafeJson.asMap(body['pagination']);

      list.addAll(raw.map(WarpingListItem.fromJson));
      hasMore.value = SafeJson.asBool(pag['hasMore']);
      _page++;
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load warpings';
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

  int get openCount       => list.where((w) => w.status == 'open').length;
  int get inProgressCount => list.where((w) => w.status == 'in_progress').length;
  int get completedCount  => list.where((w) => w.status == 'completed').length;
}
