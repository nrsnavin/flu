import 'package:get/get.dart';
import 'package:dio/dio.dart';

class CustomerDetailController extends GetxController {
  final String customerId;

  CustomerDetailController({required this.customerId});

  final loading = false.obs;
  final customer = <String, dynamic>{}.obs;

  final Dio dio = Dio(
    BaseOptions(baseUrl: "http://13.233.117.153:2701/api/v2/customer"),
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

      customer.value = res.data['customer'];
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
