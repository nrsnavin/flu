import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

class SupplierController extends GetxController {
  final Dio _dio = ApiClient.buildClient(baseUrl: "http://13.233.117.153:2701/api/v2/supplier");

  RxList suppliers = [].obs;
  RxBool isLoading = false.obs;

  Future<void> fetchSuppliers({String search = ""}) async {
    try {
      isLoading.value = true;

      final res = await _dio.get(
        "/get-suppliers",
        queryParameters: {
          "search": search,
          "limit": 50,
        },
      );

      suppliers.value = res.data["suppliers"];
    } catch (e) {
      Get.snackbar("Error", "Failed to load suppliers");
    } finally {
      isLoading.value = false;
    }
  }
}
