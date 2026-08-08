import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/elastic_history.dart';

// ══════════════════════════════════════════════════════════════
//  ELASTIC PRODUCT HISTORY
//
//  Two independently paged lists behind one controller: the orders this
//  elastic has been on, and the jobs that ran it. Paged rather than
//  fetched whole, because a product in the catalogue for years has
//  hundreds of each.
//
//  Deleted orders and cancelled jobs are hidden by default and can be
//  asked for. A deleted order is not history, it is a mistake being
//  undone; a cancelled job made nothing but is still part of the record
//  of what was attempted, which is a different thing.
// ══════════════════════════════════════════════════════════════

const _pageSize = 20;

class ElasticHistoryController extends GetxController {
  final String elasticId;
  final String elasticName;
  ElasticHistoryController({required this.elasticId, required this.elasticName});

  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/elastic');

  // ── Orders ────────────────────────────────────────────────
  final orders          = <ElasticOrderRow>[].obs;
  final ordersTotal     = 0.obs;
  final ordersHasMore   = false.obs;
  final ordersLoading   = false.obs;
  final ordersLoadingMore = false.obs;
  final ordersError     = Rxn<String>();
  final includeDeleted  = false.obs;
  int _ordersPage = 1;

  // ── Jobs ──────────────────────────────────────────────────
  final jobs            = <ElasticJobRow>[].obs;
  final jobsTotal       = 0.obs;
  final jobsHasMore     = false.obs;
  final jobsLoading     = false.obs;
  final jobsLoadingMore = false.obs;
  final jobsError       = Rxn<String>();
  final includeCancelled = false.obs;
  int _jobsPage = 1;

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
    fetchJobs();
    // Changing what is counted as history re-reads from page one — a
    // toggle that only affected the next page would leave the list a
    // mixture of two different questions.
    ever(includeDeleted, (_) => fetchOrders());
    ever(includeCancelled, (_) => fetchJobs());
  }

  String _msg(Object e, String fallback) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) return d['message'].toString();
    }
    return fallback;
  }

  // ── Orders ────────────────────────────────────────────────

  Future<void> fetchOrders() async {
    ordersLoading.value = true;
    ordersError.value = null;
    _ordersPage = 1;
    try {
      final page = await _ordersPageAt(1);
      orders.value = page.rows;
      ordersTotal.value = page.total;
      ordersHasMore.value = page.hasMore;
    } catch (e) {
      ordersError.value = _msg(e, 'Failed to load orders');
    } finally {
      ordersLoading.value = false;
    }
  }

  Future<void> loadMoreOrders() async {
    if (!ordersHasMore.value || ordersLoadingMore.value) return;
    ordersLoadingMore.value = true;
    try {
      final page = await _ordersPageAt(_ordersPage + 1);
      _ordersPage += 1;
      orders.addAll(page.rows);
      ordersTotal.value = page.total;
      ordersHasMore.value = page.hasMore;
    } catch (e) {
      ordersError.value = _msg(e, 'Failed to load more orders');
    } finally {
      ordersLoadingMore.value = false;
    }
  }

  Future<ElasticHistoryPage<ElasticOrderRow>> _ordersPageAt(int page) async {
    final res = await _dio.get('/$elasticId/orders', queryParameters: {
      'page': page,
      'limit': _pageSize,
      if (includeDeleted.value) 'includeDeleted': 'true',
    });
    return ElasticHistoryPage.of(
      res.data as Map<String, dynamic>, 'orders', ElasticOrderRow.fromJson,
    );
  }

  // ── Jobs ──────────────────────────────────────────────────

  Future<void> fetchJobs() async {
    jobsLoading.value = true;
    jobsError.value = null;
    _jobsPage = 1;
    try {
      final page = await _jobsPageAt(1);
      jobs.value = page.rows;
      jobsTotal.value = page.total;
      jobsHasMore.value = page.hasMore;
    } catch (e) {
      jobsError.value = _msg(e, 'Failed to load jobs');
    } finally {
      jobsLoading.value = false;
    }
  }

  Future<void> loadMoreJobs() async {
    if (!jobsHasMore.value || jobsLoadingMore.value) return;
    jobsLoadingMore.value = true;
    try {
      final page = await _jobsPageAt(_jobsPage + 1);
      _jobsPage += 1;
      jobs.addAll(page.rows);
      jobsTotal.value = page.total;
      jobsHasMore.value = page.hasMore;
    } catch (e) {
      jobsError.value = _msg(e, 'Failed to load more jobs');
    } finally {
      jobsLoadingMore.value = false;
    }
  }

  Future<ElasticHistoryPage<ElasticJobRow>> _jobsPageAt(int page) async {
    final res = await _dio.get('/$elasticId/jobs', queryParameters: {
      'page': page,
      'limit': _pageSize,
      if (includeCancelled.value) 'includeCancelled': 'true',
    });
    return ElasticHistoryPage.of(
      res.data as Map<String, dynamic>, 'jobs', ElasticJobRow.fromJson,
    );
  }

  // ── Roll-ups over what has been LOADED ────────────────────
  //
  // Deliberately named as such wherever they are shown. These are sums
  // over the pages fetched so far, not over everything the server holds
  // — a total that silently meant "the first 20" would be worse than no
  // total at all.

  double get orderedLoaded => orders.fold(0.0, (s, o) => s + o.ordered);
  double get packedLoaded  => orders.fold(0.0, (s, o) => s + o.packed);
  double get producedLoaded => jobs.fold(0.0, (s, j) => s + j.produced);
  double get wastageLoaded => jobs.fold(0.0, (s, j) => s + j.wastage);

  bool get ordersComplete => orders.length >= ordersTotal.value;
  bool get jobsComplete   => jobs.length >= jobsTotal.value;
}
