import 'package:dio/dio.dart';

class POApiService {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2/supplier",
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {"Content-Type": "application/json"},
    ),
  );

  // Supplier & RawMaterial lists are fetched from their own routers
  static final Dio supplierDio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2/supplier",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static final Dio materialDio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2/materials",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}