import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../../core/server_pdf.dart';
import '../models/quote.dart';

// ══════════════════════════════════════════════════════════════
//  QUOTATIONS ON A PHONE
//
//  Web-only until now. What it is worth on a phone is answering "what
//  did we quote them?" while standing in front of the customer, or on
//  the way to see them — and then recording what they said before it
//  is forgotten on the drive back.
//
//  ── What it does and does not do ───────────────────────────────
//  Reads the quote, opens the same PDF the customer received, and
//  moves the status: sent, accepted, declined. Those are decisions
//  made in a room with somebody, and a quote that sits on "draft" for
//  a week because nobody was at a desk is the whole reason to have
//  this here.
//
//  BUILDING one stays on the web. A quote line is a costing —
//  materials at weight and rate, a conversion cost, a margin, then
//  tax. Every one of those is typed from a paper somebody is holding,
//  and a mistyped margin goes out under the company's name as a price
//  it has to honour. That is a desk job. Reading one back, and saying
//  yes or no to it, is not.
//
//  ── The PDF is the server's, deliberately ──────────────────────
//  Not re-rendered in Dart. The customer is holding a document with a
//  number on it; a second renderer is a second set of rounding, and
//  two papers with the same quote number and different totals is a
//  worse outcome than no PDF on the phone at all.
// ══════════════════════════════════════════════════════════════

String quoteMessage(Object e, String fallback) {
  if (e is ServerPdfError) return e.message;
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

bool isForbidden(Object e) =>
    e is DioException && e.response?.statusCode == 403;

/// The statuses a person can move a quote TO from this screen.
///
/// 'expired' is absent on purpose: it is a fact about the date, not a
/// decision, and offering it as a button would let somebody mark a
/// live quote dead by tapping the wrong row.
const kQuoteActions = <String, String>{
  'sent': 'Mark sent',
  'accepted': 'Accepted',
  'declined': 'Declined',
};

class QuoteApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/quote');

  static Future<QuotePage> list({
    int page = 1,
    String? search,
    String? status,
  }) async {
    final res = await _dio.get('/list', queryParameters: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return QuotePage.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  static Future<Quote> detail(String id) async {
    final res = await _dio.get('/detail', queryParameters: {'id': id});
    final body = Map<String, dynamic>.from(res.data as Map);
    // The route has been through a rename; accept either envelope
    // rather than breaking on the one this deployment happens to send.
    final raw = body['quote'] ?? body['data'] ?? body;
    return Quote.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static Future<Quote> setStatus(String id, String status) async {
    final res = await _dio.patch('/status', data: {'id': id, 'status': status});
    final body = Map<String, dynamic>.from(res.data as Map);
    final raw = body['quote'] ?? body['data'] ?? body;
    return Quote.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// The strict path, not fetchServerPdf(): there is no local
  /// quotation generator to fall back to, so a silent null would be a
  /// button that does nothing.
  static Future<void> openPdf(Quote q) => openServerPdf(
        '/quote/${q.id}/pdf',
        filename: 'Quotation ${q.quoteNo}',
      );
}

class QuoteListController extends GetxController {
  final quotes = <Quote>[].obs;
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final search = ''.obs;
  final status = RxnString();
  final page = 1.obs;
  final pages = 1.obs;
  final total = 0.obs;

  Timer? _debounce;

  /// null = every status.
  static const statusFilters = [
    null, 'draft', 'sent', 'accepted', 'declined', 'expired',
  ];

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await QuoteApi.list(
        page: page.value,
        search: search.value,
        status: status.value,
      );
      quotes.value = res.quotes;
      total.value = res.total;
      pages.value = res.pages;
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to quotations.'
          : quoteMessage(e, 'Could not load quotations');
    } finally {
      isLoading.value = false;
    }
  }

  /// Typing should not fire a request per keystroke.
  void setSearch(String s) {
    search.value = s;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      page.value = 1;
      fetch();
    });
  }

  void setStatus(String? s) {
    if (s == status.value) return;
    status.value = s;
    page.value = 1;
    fetch();
  }

  Future<void> goToPage(int p) async {
    if (p < 1 || p > pages.value || p == page.value) return;
    page.value = p;
    await fetch();
  }

  /// Keep the row in step after the detail screen changed a status,
  /// without re-paging the whole list underneath somebody's thumb.
  void replace(Quote q) {
    final i = quotes.indexWhere((x) => x.id == q.id);
    if (i >= 0) quotes[i] = q;
  }
}

class QuoteDetailController extends GetxController {
  QuoteDetailController(this.quoteId);

  final String quoteId;

  final quote = Rxn<Quote>();
  final isLoading = false.obs;
  final isBusy = false.obs;
  final isDownloading = false.obs;
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

  /// Returns null on success, or a message to show.
  Future<String?> setStatus(String status) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      quote.value = await QuoteApi.setStatus(quoteId, status);
      // Whoever pushed this screen may be showing the same row.
      if (Get.isRegistered<QuoteListController>()) {
        Get.find<QuoteListController>().replace(quote.value!);
      }
      return null;
    } catch (e) {
      return quoteMessage(e, 'Could not update the quotation');
    } finally {
      isBusy.value = false;
    }
  }

  Future<String?> openPdf() async {
    final q = quote.value;
    if (q == null) return null;
    isDownloading.value = true;
    try {
      await QuoteApi.openPdf(q);
      return null;
    } catch (e) {
      return quoteMessage(e, 'Could not open the quotation PDF');
    } finally {
      isDownloading.value = false;
    }
  }
}
