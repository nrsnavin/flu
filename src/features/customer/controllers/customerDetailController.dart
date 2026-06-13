import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';

class CustomerDetailController extends GetxController {
  final String customerId;

  CustomerDetailController({required this.customerId});

  final loading = false.obs;
  final customer = <String, dynamic>{}.obs;

  // Route through ApiClient.buildClient so the JWT cookie attaches.
  final Dio dio = ApiClient.buildClient(
    baseUrl: "http://13.233.117.153:2701/api/v2/customer",
  );

  @override
  void onInit() {
    super.onInit();
    fetchCustomer();
  }

  Future<void> fetchCustomer() async {
    try {
      loading.value = true;

      final res = await dio.get(
        "/customerDetail?id=$customerId",
      );

      final body = res.data is Map ? res.data['customer'] : null;
      if (body is Map) {
        customer.assignAll(Map<String, dynamic>.from(body));
      } else {
        customer.clear();
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load customer details");
    } finally {
      loading.value = false;
    }
  }

  Future<void> deleteCustomer() async {
    try {
      await dio.delete(
        "/delete-customer?id=$customerId"
      );
      Get.snackbar("Deleted", "Customer removed successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to delete customer");
    }
  }

}
