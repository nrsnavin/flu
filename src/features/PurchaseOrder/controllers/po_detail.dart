import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/po_models.dart';
import '../services/api.dart';


/// The server's own message, when it sent one.
///
/// It is the side that knows whether the id was unknown, the session
/// had expired, or the PO was deleted — and it says so in words.
/// Anything invented here would be a guess dressed as an explanation.
String _dioMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final m = data['message']?.toString();
    if (m != null && m.trim().isNotEmpty) return m;
  }
  if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
    return 'Your session has expired. Sign in again.';
  }
  if (e.response != null) {
    return 'The server refused that (${e.response!.statusCode}).';
  }
  // No response at all — the request never arrived. A different thing
  // to do next from "not found", so it reads differently.
  return 'Could not reach the server. Check the connection and retry.';
}

class PODetailController extends GetxController {
  final String poId;
  PODetailController(this.poId);

  final loading = true.obs;
  final Rxn<POModel> po = Rxn<POModel>();
  final inwardHistory = <InwardRecord>[].obs;

  /// Why the load failed, in the SERVER'S words where it gave any.
  ///
  /// This screen used to catch everything and raise one snackbar
  /// reading "Failed to load PO details". A snackbar is gone in three
  /// seconds and says nothing, so a PO that would not open looked
  /// identical whether the id was wrong, the session had expired, the
  /// server was down, or one line of the response failed to parse —
  /// and the person reporting it had nothing to report but "it does
  /// not load". Kept on the controller so the page can show it,
  /// beside a retry, until it is dealt with.
  final errorMsg = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      loading.value = true;
      errorMsg.value = null;

      final res = await POApiService.dio.get(
        "/get-po-detail",
        queryParameters: {"id": poId},
      );

      final body = res.data;
      if (body is! Map || body["po"] == null) {
        // A 200 with no PO is a contract break, not a missing PO.
        // Saying "not found" for it would send somebody hunting for a
        // purchase order that is sitting right there.
        throw const FormatException(
            'The server answered, but sent no purchase order.');
      }

      po.value = POModel.fromJson(Map<String, dynamic>.from(body["po"]));

      // Tolerated as absent: a PO with no receipts against it yet is
      // the ordinary case, and the previous cast threw on null —
      // taking the whole page down over an empty history.
      inwardHistory.assignAll(
        (body["inwardHistory"] as List? ?? const [])
            .whereType<Map>()
            .map((e) => InwardRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } on DioException catch (e) {
      errorMsg.value = _dioMessage(e);
    } catch (e) {
      // Anything else is a parse fault on our side. Say so rather than
      // blaming the network, because the two need different fixes.
      errorMsg.value = 'Could not read the purchase order: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> clonePO() async {
    try {
      loading.value = true;
      final res = await POApiService.dio.post("/clone-po", data: {"id": poId});
      final cloned = POModel.fromJson(res.data["po"]);
      Get.snackbar("Success", "PO #${cloned.poNo} created from clone");
    } catch (e) {
      Get.snackbar("Error", "Failed to clone PO");
    } finally {
      loading.value = false;
    }
  }

  /// Soft-deletes (cancels) an Open PO with no receipts. Requires an audit
  /// reason; the server stamps a PO_DELETED fingerprint. Returns true on
  /// success so the caller can pop back to the list.
  Future<bool> deletePO(String auditReason) async {
    try {
      loading.value = true;
      await POApiService.dio.delete(
        "/delete-po",
        queryParameters: {"poId": poId, "auditReason": auditReason},
      );
      Get.snackbar("Deleted", "Purchase order cancelled");
      return true;
    } catch (e) {
      final msg = e is DioException
          ? (e.response?.data is Map ? e.response?.data["message"] : null)
          : null;
      Get.snackbar("Error", msg?.toString() ?? "Failed to delete PO");
      return false;
    } finally {
      loading.value = false;
    }
  }
}