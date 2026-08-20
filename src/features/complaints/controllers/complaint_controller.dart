import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/complaint.dart';

// ══════════════════════════════════════════════════════════════
//  CUSTOMER COMPLAINTS ON THE FLOOR
//
//  Web-only until now. It belongs on a phone for one reason: the
//  person who can confirm a shade complaint is standing next to the
//  cloth, and the trace tells them which OTHER jobs came off the same
//  yarn lot — which is the difference between apologising to one
//  customer and stopping a second delivery before it leaves.
//
//  ── Raising and resolving stay on the web ──────────────────────
//  A complaint is a customer-facing record with a written reason and
//  a resolution that goes into a reply. Typing that on a phone
//  between two machines produces the kind of terse note nobody can
//  use six months later. This reads, and it traces.
// ══════════════════════════════════════════════════════════════

String complaintMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

bool isForbidden(Object e) =>
    e is DioException && e.response?.statusCode == 403;

class ComplaintApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/complaint');

  static Future<ComplaintPage> list({
    int page = 1,
    int limit = 50,
    String? status,
    String? category,
  }) async {
    final res = await _dio.get('/', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    return ComplaintPage.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<Complaint> detail(String id) async {
    final res = await _dio.get('/$id');
    return Complaint.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  /// Everything else that shares a yarn lot with this complaint's job.
  static Future<ComplaintTrace> trace(String id) async {
    final res = await _dio.get('/$id/trace');
    return ComplaintTrace.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map));
  }
}

class ComplaintListController extends GetxController {
  final items = <Complaint>[].obs;
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final status = RxnString();
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
      final res = await ComplaintApi.list(page: page.value, status: status.value);
      items.value = res.items;
      total.value = res.total;
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to complaints.'
          : complaintMessage(e, 'Could not load complaints');
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

class ComplaintDetailController extends GetxController {
  ComplaintDetailController(this.complaintId);

  final String complaintId;

  final complaint = Rxn<Complaint>();
  final trace = Rxn<ComplaintTrace>();
  final isLoading = false.obs;
  final isTracing = false.obs;
  final errorMsg = RxnString();
  final traceError = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      complaint.value = await ComplaintApi.detail(complaintId);
    } catch (e) {
      errorMsg.value = isForbidden(e)
          ? 'You do not have access to complaints.'
          : complaintMessage(e, 'Could not load this complaint');
    } finally {
      isLoading.value = false;
    }
  }

  /// On demand, not on open. The trace walks lots to batches to jobs
  /// and is the expensive part; most people open a complaint to read
  /// it, and only some go looking for who else is affected.
  Future<void> loadTrace() async {
    if (isTracing.value) return;
    isTracing.value = true;
    traceError.value = null;
    try {
      trace.value = await ComplaintApi.trace(complaintId);
    } catch (e) {
      traceError.value = complaintMessage(e, 'Could not trace this complaint');
    } finally {
      isTracing.value = false;
    }
  }
}
