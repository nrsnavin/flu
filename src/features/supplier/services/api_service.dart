import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

class SupplierApiService {
  static final Dio dio = ApiClient.buildClient(baseUrl: "http://13.233.117.153:2701/api/v2/supplier");
}
