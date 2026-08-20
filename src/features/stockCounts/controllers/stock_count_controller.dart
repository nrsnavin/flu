import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/stock_count.dart';

// ══════════════════════════════════════════════════════════════
//  PHYSICAL INVENTORY ON A PHONE
//
//  This is the one module where the phone is the RIGHT device and the
//  desk is the wrong one. Counting stock means standing in front of a
//  rack with the material in your hands; doing it on a laptop means
//  writing figures on paper first and typing them in afterwards, which
//  is where counts go wrong.
//
//  ── What stays on the web ──────────────────────────────────────
//  Posting. It applies every variance as a stock adjustment and cannot
//  be undone, and the API gates it to admin/accounts anyway. Opening a
//  new sheet stays too — choosing a scope is a planning decision made
//  before anyone walks anywhere. So this app does the walking part:
//  read the sheet, enter what is on the rack, explain the gaps.
//
//  ── Saving is incremental and merges ───────────────────────────
//  PATCH /:id/lines sends only the lines that changed, and the server
//  merges rather than replaces, so two people can count different racks
//  of the same sheet without wiping each other's work. That is why this
//  tracks a dirty set instead of posting the whole sheet back.
// ══════════════════════════════════════════════════════════════

String countMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

/// Whether the failure was the feature being withheld from this user.
bool isForbidden(Object e) =>
    e is DioException && e.response?.statusCode == 403;

class StockCountApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/stock-counts');

  static Future<StockCountListPage> list({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final res = await _dio.get('/', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return StockCountListPage.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<StockCount> sheet(String id) async {
    final res = await _dio.get('/$id');
    return StockCount.fromJson(
        Map<String, dynamic>.from(res.data['count'] as Map));
  }

  /// Save counted quantities. `lines` carries only what changed.
  static Future<StockCount> saveLines(
    String id,
    List<Map<String, dynamic>> lines,
  ) async {
    final res = await _dio.patch('/$id/lines', data: {'lines': lines});
    return StockCount.fromJson(
        Map<String, dynamic>.from(res.data['count'] as Map));
  }
}

// ── The list ──────────────────────────────────────────────────
class StockCountListController extends GetxController {
  final counts = <StockCount>[].obs;
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final status = RxnString();          // null = every status
  final page = 1.obs;
  final pages = 1.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch({int? toPage}) async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await StockCountApi.list(
        page: toPage ?? page.value,
        status: status.value,
      );
      counts.value = res.counts;
      page.value = res.page;
      pages.value = res.pages;
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to stock counts.'
          : countMessage(e, 'Could not load stock counts');
    } finally {
      isLoading.value = false;
    }
  }

  void setStatus(String? s) {
    status.value = s;
    page.value = 1;
    fetch();
  }
}

// ── One sheet, being counted ──────────────────────────────────
class StockCountSheetController extends GetxController {
  StockCountSheetController(this.countId);

  final String countId;

  final sheet = Rxn<StockCount>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMsg = RxnString();

  /// Only the rack in front of you, when the sheet is long.
  final query = ''.obs;

  /// Lines edited since the last save, by line id. Nothing else is
  /// sent, so a second counter's work on other lines is never
  /// overwritten by ours.
  final _dirty = <String, Map<String, dynamic>>{};

  bool get hasUnsaved => _dirty.isNotEmpty;
  int get unsavedCount => _dirty.length;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      sheet.value = await StockCountApi.sheet(countId);
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to stock counts.'
          : countMessage(e, 'Could not load this count');
    } finally {
      isLoading.value = false;
    }
  }

  /// The lines to show, narrowed by the search box.
  List<StockCountLine> get visible {
    final s = sheet.value;
    if (s == null) return const [];
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return s.lines;
    return s.lines
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.category.toLowerCase().contains(q))
        .toList();
  }

  /// Record a counted quantity locally. Null clears it back to
  /// uncounted, which is NOT the same as zero — see the model.
  void setCounted(StockCountLine line, double? counted) {
    final s = sheet.value;
    if (s == null) return;
    final idx = s.lines.indexWhere((l) => l.id == line.id);
    if (idx < 0) return;

    final updated = List<StockCountLine>.from(s.lines);
    updated[idx] = line.copyWith(countedQty: counted);
    sheet.value = StockCount(
      id: s.id, countNo: s.countNo, label: s.label, status: s.status,
      frozenAt: s.frozenAt, postedAt: s.postedAt, cancelledAt: s.cancelledAt,
      cancelledReason: s.cancelledReason, lines: updated, totals: s.totals,
    );

    _dirty[line.id] = {
      'lineId': line.id,
      'countedQty': counted,
      if (line.reason.isNotEmpty) 'reason': line.reason,
    };
  }

  void setReason(StockCountLine line, String reason) {
    final entry = _dirty[line.id] ?? {'lineId': line.id};
    entry['reason'] = reason;
    _dirty[line.id] = entry;
  }

  /// Returns null on success, or a message to show.
  Future<String?> save() async {
    if (_dirty.isEmpty) return null;
    isSaving.value = true;
    try {
      final payload = _dirty.values.toList();
      sheet.value = await StockCountApi.saveLines(countId, payload);
      _dirty.clear();
      return null;
    } catch (e) {
      // NO_LINES_APPLIED means the server rejected every line — a
      // partial save that reported success is how a count silently
      // loses an afternoon of walking.
      return countMessage(e, 'Could not save the count');
    } finally {
      isSaving.value = false;
    }
  }
}
