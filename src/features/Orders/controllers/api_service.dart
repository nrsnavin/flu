import 'package:production/src/core/api_client.dart';

class ApiService {
  static Future<List<dynamic>> fetchCustomers() async {
    final res = await ApiClient.instance.dio.get('/customer/all-customers');
    return res.data['customers'];
  }

  static Future<List<dynamic>> fetchElastics() async {
    final res = await ApiClient.instance.dio.get('/elastic/get-elastics');
    return res.data['elastics'];
  }

  static Future<void> createOrder(Map<String, dynamic> payload) async {
    await ApiClient.instance.dio.post('/order/create-order', data: payload);
  }
}
