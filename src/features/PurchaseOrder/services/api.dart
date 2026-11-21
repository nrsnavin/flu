import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

class POApiService {
  static final Dio dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/supplier');

  // Supplier & RawMaterial lists are fetched from their own routers
  static final Dio supplierDio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/supplier');

  static final Dio materialDio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/materials');

  // Our GSTIN / state and the default GST rate, for the PO form's tax preview.
  static final Dio settingsDio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/settings');
}
