import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

class SupplierController extends GetxController {
  final Dio _dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/supplier');

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
