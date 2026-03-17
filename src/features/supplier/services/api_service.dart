import 'package:dio/dio.dart';

class SupplierApiService {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2/supplier", // 🔁 change
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        "Content-Type": "application/json",
      },
    ),
  );
}
