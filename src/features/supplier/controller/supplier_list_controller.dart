
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../services/api_service.dart';

class SupplierListController extends GetxController {
  final suppliers = <Map<String, dynamic>>[].obs;
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSuppliers();
  }

  Future<void> fetchSuppliers() async {
    try {
      loading.value = true;
      final res = await SupplierApiService.dio.get("/get-suppliers");
      suppliers.assignAll(
        List<Map<String, dynamic>>.from(res.data["suppliers"]),
      );
    } finally {
      loading.value = false;
    }
  }

  Future<void> deleteSupplier(String id) async {
    await SupplierApiService.dio.delete(
      "/delete-supplier",
      queryParameters: {"id": id},
    );
    fetchSuppliers();
  }
}
