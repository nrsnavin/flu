import 'package:get/get.dart';
import '../models/po_models.dart';
import '../services/api.dart';


class PODetailController extends GetxController {
  final String poId;
  PODetailController(this.poId);

  final loading = true.obs;
  final Rxn<POModel> po = Rxn<POModel>();
  final inwardHistory = <InwardRecord>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      loading.value = true;
      final res = await POApiService.dio.get(
        "/get-po-detail",
        queryParameters: {"id": poId},
      );

      po.value = POModel.fromJson(res.data["po"]);

      inwardHistory.assignAll(
        (res.data["inwardHistory"] as List)
            .map((e) => InwardRecord.fromJson(e))
            .toList(),
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to load PO details");
    } finally {
      loading.value = false;
    }
  }

  Future<void> clonePO() async {
    try {
      loading.value = true;
      final res = await POApiService.dio.post("/clone-po", data: {"id": poId});
      final cloned = POModel.fromJson(res.data["po"]);
      Get.snackbar("Success", "PO #${cloned.poNo} created from clone");
    } catch (e) {
      Get.snackbar("Error", "Failed to clone PO");
    } finally {
      loading.value = false;
    }
  }
}