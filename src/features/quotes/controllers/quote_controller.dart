import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/quote.dart';

// ══════════════════════════════════════════════════════════════
//  QUOTATIONS, READ-ONLY
//
//  Web-only until now. What it is worth on a phone is answering "what
//  did we quote them?" while standing in front of the customer, or on
//  the way to see them.
//
//  ── Building one stays on the web, and that is not laziness ────
//  A quote line is a costing: materials at weight and rate, a
//  conversion cost, a margin, then tax. Every one of those is typed
//  from a paper somebody is holding, and a mistyped margin goes out
//  under the company's name as a price it has to honour. That is a
//  desk job. Reading one back is not.
// ══════════════════════════════════════════════════════════════

String quoteMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

bool isForbidden(Object e) =>
    e is DioException && e.response?.statusCode == 403;

class QuoteApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/quote');

  static Future<QuotePage> list({int page = 1, String? search}) async {
    final res = await _dio.get('/list', queryParameters: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return QuotePage.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<Quote> detail(String id) async {
    final res = await _dio.get('/detail', queryParameters: {'id': id});
    final body = res.data as Map<String, dynamic>;
    // The route has been through a rename; accept either envelope
    // rather than breaking on the one this deployment happens to send.
    final raw = body['quote'] ?? body['data'] ?? body;
    return Quote.fromJson(Map<String, dynamic>.from(raw as Map));
  }
}

class QuoteListController extends GetxController {
  final quotes = <Quote>[].obs;
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final search = ''.obs;
  final page = 1.obs;
  final total = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await QuoteApi.list(page: page.value, search: search.value);
      quotes.value = res.quotes;
      total.value = res.total;
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to quotations.'
          : quoteMessage(e, 'Could not load quotations');
    } finally {
      isLoading.value = false;
    }
  }

  void setSearch(String s) {
    search.value = s;
    page.value = 1;
    fetch();
  }
}

class QuoteDetailController extends GetxController {
  QuoteDetailController(this.quoteId);

  final String quoteId;

  final quote = Rxn<Quote>();
  final isLoading = false.obs;
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
      quote.value = await QuoteApi.detail(quoteId);
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to quotations.'
          : quoteMessage(e, 'Could not load this quotation');
    } finally {
      isLoading.value = false;
    }
  }
}
