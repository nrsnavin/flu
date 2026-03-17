import 'package:get/get.dart';
import '../models/po_models.dart';
import '../services/api.dart';


class POListController extends GetxController {
  final pos = <POModel>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;

  // Filters
  final statusFilter = "".obs; // "" = All, Open, Partial, Completed
  final searchQuery = "".obs;

  // Pagination
  int _page = 1;
  final int _limit = 20;
  final hasMore = false.obs;
  final total = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPOs(reset: true);

    // Re-fetch on filter change (debounced)
    debounce(
      statusFilter,
          (_) => fetchPOs(reset: true),
      time: const Duration(milliseconds: 300),
    );
    debounce(
      searchQuery,
          (_) => fetchPOs(reset: true),
      time: const Duration(milliseconds: 500),
    );
  }

  Future<void> fetchPOs({bool reset = false}) async {
    if (reset) {
      _page = 1;
      pos.clear();
    }

    if (_page == 1) {
      loading.value = true;
    } else {
      loadingMore.value = true;
    }

    try {
      final params = <String, dynamic>{
        "page": _page,
        "limit": _limit,
      };
      if (statusFilter.value.isNotEmpty) params["status"] = statusFilter.value;
      if (searchQuery.value.isNotEmpty) params["search"] = searchQuery.value;

      final res = await POApiService.dio.get(
        "/get-pos",
        queryParameters: params,
      );

      final fetched = (res.data["pos"] as List)
          .map((e) => POModel.fromJson(e))
          .toList();

      if (reset) {
        pos.assignAll(fetched);
      } else {
        pos.addAll(fetched);
      }

      final pagination = res.data["pagination"];
      total.value = pagination["total"] ?? 0;
      hasMore.value = pagination["hasMore"] ?? false;
      if (hasMore.value) _page++;
    } catch (e) {
      Get.snackbar("Error", "Failed to load Purchase Orders");
    } finally {
      loading.value = false;
      loadingMore.value = false;
    }
  }

  Future<void> deletePO(String id) async {
    try {
      await POApiService.dio.delete("/delete-po", queryParameters: {"id": id});
      pos.removeWhere((p) => p.id == id);
      Get.snackbar("Success", "Purchase Order deleted");
    } catch (e) {
      Get.snackbar("Error", "Failed to delete PO");
    }
  }

  Future<void> clonePO(String id) async {
    try {
      loading.value = true;
      await POApiService.dio.post("/clone-po", data: {"id": id});
      Get.snackbar("Success", "PO cloned successfully");
      fetchPOs(reset: true);
    } catch (e) {
      Get.snackbar("Error", "Failed to clone PO");
    } finally {
      loading.value = false;
    }
  }
}