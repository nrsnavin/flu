import 'dart:async';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/features/elastic/models/elastic_list_model.dart';

// ══════════════════════════════════════════════════════════════
//  ElasticListController
//  FIX: added try/catch — missing before, so any network error left
//       loading.value = true forever (spinner never cleared).
// ══════════════════════════════════════════════════════════════
class ElasticListController extends GetxController {
  final _dio = Dio(BaseOptions(
    baseUrl: "http://13.233.117.153:2701/api/v2/elastic",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final elastics  = <ElasticListModel>[].obs;
  final loading   = false.obs;
  final hasMore   = true.obs;
  final search    = "".obs;

  int _page = 1;
  static const _limit = 20;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchElastics(reset: true);
  }

  Future<void> fetchElastics({bool reset = false}) async {
    if (loading.value) return;

    if (reset) {
      _page = 1;
      hasMore.value = true;
      elastics.clear();
    }
    if (!hasMore.value) return;

    try {
      loading.value = true;
      final res = await _dio.get("/get-elastics", queryParameters: {
        "search": search.value,
        "page":   _page,
        "limit":  _limit,
      });

      final fetched = (res.data["elastics"] as List? ?? [])
          .map((e) => ElasticListModel.fromJson(e))
          .toList();

      if (fetched.length < _limit) hasMore.value = false;
      elastics.addAll(fetched);
      _page++;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to load elastics";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false; // FIX: always reset
    }
  }

  void onSearchChanged(String value) {
    search.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      fetchElastics(reset: true);
    });
  }

  void loadMore() {
    if (!loading.value && hasMore.value) fetchElastics();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}

// ══════════════════════════════════════════════════════════════
//  ElasticDetailController
//  FIX: added catch block — errors were silently swallowed before,
//       no snackbar, no reset of loading.
// ══════════════════════════════════════════════════════════════
class ElasticDetailController extends GetxController {
  final _dio = Dio(BaseOptions(
    baseUrl: "http://13.233.117.153:2701/api/v2/elastic",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final String elasticId;
  ElasticDetailController(this.elasticId);

  final loading = true.obs;
  final elastic = <String, dynamic>{}.obs;
  final costing = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      loading.value = true;
      final res = await _dio.get(
        "/get-elastic-detail",
        queryParameters: {"id": elasticId},
      );
      elastic.value = Map<String, dynamic>.from(res.data["elastic"]);
      costing.value = Map<String, dynamic>.from(
          res.data["elastic"]["costing"] ?? {});
    } on DioException catch (e) {
      // FIX: was completely missing — errors silently swallowed
      final msg = e.response?.data?['message'] ?? "Failed to load elastic";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }
}