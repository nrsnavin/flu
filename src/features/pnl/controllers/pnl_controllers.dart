import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/order_pnl.dart';

// ══════════════════════════════════════════════════════════════
//  ORDER P&L — READING ONLY
//
//  The three things the P&L needs that no other screen owns — selling
//  rates, per-job cost overrides, the rate card — are all writes, and
//  all of them stay on the web. They are typed from a paper the
//  accountant is holding, in numbers that get argued over; a phone
//  standing on a factory floor is the wrong place to enter them and a
//  fat-fingered rate card re-costs every order in the factory.
//
//  So this reads. What it reads is worth having on a phone: whether the
//  order in front of you is making money.
// ══════════════════════════════════════════════════════════════

/// Whether a failure was the `/order-pnl` feature being withheld.
/// Margin is deliberately its own permission — opening an order and
/// seeing the profit on it are different things — so a refusal here is
/// a normal state to be explained, not an error to be dumped.
bool isForbidden(Object e) =>
    e is DioException && e.response?.statusCode == 403;

String pnlMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

class PnlApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/pnl');

  static Future<PnlListPage> orders({
    int page = 1,
    int limit = 25,
    String sort = 'recent',
    String? status,
    String? customerId,
  }) async {
    final res = await _dio.get('/orders', queryParameters: {
      'page': page,
      'limit': limit,
      'sort': sort,
      if (status != null && status.isNotEmpty) 'status': status,
      if (customerId != null && customerId.isNotEmpty) 'customer': customerId,
    });
    return PnlListPage.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<OrderPnl> order(String orderId) async {
    final res = await _dio.get('/order/$orderId');
    return OrderPnl.fromJson(res.data['pnl'] as Map<String, dynamic>);
  }

  static Future<PnlRateCard> settings() async {
    final res = await _dio.get('/settings');
    return PnlRateCard.fromJson(res.data['settings'] as Map<String, dynamic>);
  }

  static Future<Uint8List> pdf(String orderId) async {
    final res = await _dio.get<List<int>>(
      '/order/$orderId.pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }
}

class PnlListController extends GetxController {
  final page   = PnlListPage.empty.obs;
  final loading = true.obs;
  final errorMsg = Rxn<String>();
  final forbidden = false.obs;

  /// recent · margin · profit · value
  final sort = 'recent'.obs;
  final statusFilter = ''.obs;
  final pageNo = 1.obs;

  static const sorts = ['recent', 'margin', 'profit', 'value'];

  static String sortLabel(String s) {
    switch (s) {
      case 'margin': return 'Margin %';
      case 'profit': return 'Profit ₹';
      case 'value':  return 'Order value';
      default:       return 'Newest';
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetch();
    // Both re-read from page one. A sort applied only to the next page
    // would leave the list a mixture of two different questions.
    ever(sort, (_) { pageNo.value = 1; fetch(); });
    ever(statusFilter, (_) { pageNo.value = 1; fetch(); });
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    forbidden.value = false;
    try {
      page.value = await PnlApi.orders(
        page: pageNo.value,
        sort: sort.value,
        status: statusFilter.value,
      );
    } catch (e) {
      if (isForbidden(e)) {
        forbidden.value = true;
      } else {
        errorMsg.value = pnlMessage(e, 'Failed to load the P&L');
      }
    } finally {
      loading.value = false;
    }
  }

  Future<void> goToPage(int p) async {
    if (p < 1 || p > page.value.pages || p == pageNo.value) return;
    pageNo.value = p;
    await fetch();
  }

  /// True when the ranking on screen only ordered the rows fetched, not
  /// every order there is. The screen must say so.
  bool get sortedWithinPageOnly =>
      page.value.sortScope == 'page' && page.value.pages > 1;
}

class PnlDetailController extends GetxController {
  final String orderId;
  PnlDetailController(this.orderId);

  final pnl = Rxn<OrderPnl>();
  final loading = true.obs;
  final exporting = false.obs;
  final errorMsg = Rxn<String>();
  final forbidden = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    forbidden.value = false;
    try {
      pnl.value = await PnlApi.order(orderId);
    } catch (e) {
      if (isForbidden(e)) {
        forbidden.value = true;
      } else {
        errorMsg.value = pnlMessage(e, 'Failed to load the P&L');
      }
    } finally {
      loading.value = false;
    }
  }
}
