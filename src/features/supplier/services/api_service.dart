import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

class SupplierApiService {
  static final Dio dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/supplier');
}
