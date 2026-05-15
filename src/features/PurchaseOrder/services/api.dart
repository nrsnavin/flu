import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

class POApiService {
  static final Dio dio = ApiClient.buildClient(baseUrl: "http://13.233.117.153:2701/api/v2/supplier");

  // Supplier & RawMaterial lists are fetched from their own routers
  static final Dio supplierDio = ApiClient.buildClient(baseUrl: "http://13.233.117.153:2701/api/v2/supplier");

  static final Dio materialDio = ApiClient.buildClient(baseUrl: "http://13.233.117.153:2701/api/v2/materials");
}
