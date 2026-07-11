import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:production/src/core/api_client.dart';

// Mirrors GET /api/v2/order/eta-risks (prod/api/order.js).
// Orders predicted to ship late, each with a ready-to-send customer
// message (AI-drafted when a Claude key is configured, deterministic
// template otherwise). The admin reviews and sends each one manually.

class DeliveryRisk {
  final String orderId;
  final int orderNo;
  final String status;
  final String customerName;
  final String? customerPhone;
  final DateTime? promised;
  final DateTime? expectedDate;
  final int lateWorkingDays;
  final String draft;
  final bool aiDrafted;

  DeliveryRisk({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.promised,
    required this.expectedDate,
    required this.lateWorkingDays,
    required this.draft,
    required this.aiDrafted,
  });

  factory DeliveryRisk.fromJson(Map<String, dynamic> j) {
    final cust = Map<String, dynamic>.from(j['customer'] ?? {});
    DateTime? d(dynamic v) => v == null ? null : DateTime.tryParse('$v');
    return DeliveryRisk(
      orderId: '${j['orderId'] ?? ''}',
      orderNo: (j['orderNo'] as num?)?.toInt() ?? 0,
      status: '${j['status'] ?? ''}',
      customerName: '${cust['name'] ?? '—'}',
      customerPhone: cust['phone']?.toString(),
      promised: d(j['promised']),
      expectedDate: d(j['expectedDate']),
      lateWorkingDays: (j['lateWorkingDays'] as num?)?.toInt() ?? 0,
      draft: '${j['draft'] ?? ''}',
      aiDrafted: j['aiDrafted'] == true,
    );
  }

  // wa.me needs a country-coded, digits-only number. A bare 10-digit
  // Indian number gets a 91 prefix; anything already longer is kept.
  String? get whatsappNumber {
    final phone = customerPhone;
    if (phone == null) return null;
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    if (digits.length < 11) return null;
    return digits;
  }
}

class DeliveryRiskController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final risks = <DeliveryRisk>[].obs;
  final isLoading = false.obs;
  final aiDrafted = false.obs;
  final errorMsg = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get('/order/eta-risks');
      final data = res.data is Map ? res.data as Map : {};
      aiDrafted.value = data['aiDrafted'] == true;
      final list = (data['risks'] as List? ?? [])
          .map((e) => DeliveryRisk.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      risks.assignAll(list);
    } catch (_) {
      errorMsg.value = 'Could not load delivery-risk alerts';
    } finally {
      isLoading.value = false;
    }
  }
}
