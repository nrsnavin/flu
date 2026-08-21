import 'package:flutter/material.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/core/api_client.dart';
import 'package:production/src/features/Job/models/order_model.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;

// ══════════════════════════════════════════════════════════════
//  CREATE A JOB FROM AN ORDER
//
//  This screen used to refuse any quantity over what the order had
//  left — "Qty for X exceeds pending Y" — and refuse it locally,
//  before a request was ever sent. The server stopped working that way:
//  a line may be planned up to 20% over the ORDERED quantity with no
//  comment, and further with a written reason, drawing the extra yarn
//  from stock as it goes (services/excessPlanning.js).
//
//  So the app was telling the floor it could not do something the
//  system permits, with no way to find out otherwise. The rule here
//  now mirrors the server's, and the server remains the one that
//  decides — everything below exists so the answer arrives before the
//  form is filled in rather than as a 409 afterwards.
// ══════════════════════════════════════════════════════════════

/// A line may reach this much of its ordered quantity with no comment.
/// Mirrors FREE_EXCESS_PCT in services/excessPlanning.js.
const double kFreeExcessPct = 20;

/// A reason has to say something. Mirrors MIN_REASON_LENGTH there.
const int kMinReasonLength = 8;

class ElasticInput {
  final String elasticId;
  final String elasticName;

  /// What the ORDER asked for. Excess is measured against this, not
  /// against what is left — two jobs each inside the allowance must not
  /// add up to 40% over.
  final double ordered;

  /// What no job has taken yet (the API's `pending`).
  final double notAssigned;

  final TextEditingController qtyController = TextEditingController();

  /// Mirrors the text box so the excess figures can be reactive.
  final entered = 0.0.obs;

  ElasticInput({
    required this.elasticId,
    required this.elasticName,
    required this.ordered,
    required this.notAssigned,
  }) {
    qtyController.addListener(() {
      entered.value = double.tryParse(qtyController.text.trim()) ?? 0;
    });
  }

  /// What earlier jobs already planned for this line.
  double get alreadyPlanned {
    final v = ordered - notAssigned;
    return v > 0 ? v : 0;
  }

  double get totalPlanned => alreadyPlanned + entered.value;

  double get excess {
    final v = totalPlanned - ordered;
    return v > 0 ? v : 0;
  }

  /// A line with no ordered quantity has no percentage to be over by;
  /// any excess on it is unbounded, and always needs a reason.
  double get excessPct =>
      ordered > 0 ? (excess / ordered) * 100 : (excess > 0 ? double.infinity : 0);

  bool get needsReason => excessPct > kFreeExcessPct;

  void dispose() {
    qtyController.dispose();
  }
}

class AddJobOrderController extends GetxController {
  final VoidCallback? onSuccess;
  AddJobOrderController({this.onSuccess});

  Dio get _dio => ApiClient.instance.dio;

  final elasticInputs = <ElasticInput>[].obs;
  final isSubmitting = false.obs;

  final reasonController = TextEditingController();

  /// Mirrors the reason box, so the button can enable itself.
  final reason = ''.obs;

  bool _initialised = false;
  late OrderModel order;

  void initFromOrder(OrderModel o) {
    if (_initialised) return;
    _initialised = true;
    order = o;

    reasonController.addListener(() {
      reason.value = reasonController.text;
    });

    // EVERY ordered line, not only the ones with something left. A
    // fully-planned line can still take excess, and leaving it out
    // would make that impossible to do from here.
    final notAssignedById = {
      for (final p in o.pendingElastic) p.elasticId: p.quantity.toDouble(),
    };

    elasticInputs.clear();
    for (final e in o.elasticOrdered) {
      elasticInputs.add(ElasticInput(
        elasticId: e.elasticId,
        elasticName: e.elasticName,
        ordered: e.quantity.toDouble(),
        notAssigned: notAssignedById[e.elasticId] ?? 0,
      ));
    }
  }

  // ── What the entered quantities add up to ────────────────────
  List<ElasticInput> get _filled =>
      elasticInputs.where((e) => e.entered.value > 0).toList();

  List<ElasticInput> get withExcess =>
      _filled.where((e) => e.excess > 0).toList();

  bool get needsReason => _filled.any((e) => e.needsReason);

  double get totalExcess =>
      withExcess.fold<double>(0, (sum, e) => sum + e.excess);

  /// Reads the Rx rather than the controller so an Obx rebuilds as the
  /// reason is typed — the submit button enables itself on the eighth
  /// character, which is the only way anyone discovers there is a floor.
  bool get reasonOk => reason.value.trim().length >= kMinReasonLength;

  bool get canSubmit =>
      _filled.isNotEmpty && (!needsReason || reasonOk) && !isSubmitting.value;

  Future<void> submitJobOrder() async {
    final items = <Map<String, dynamic>>[];
    for (final e in _filled) {
      items.add({'elastic': e.elasticId, 'quantity': e.entered.value});
    }

    if (items.isEmpty) {
      _warn('Enter at least one elastic quantity');
      return;
    }

    if (needsReason && !reasonOk) {
      _warn(
        'Planning more than ${kFreeExcessPct.toInt()}% over needs a reason '
        'of at least $kMinReasonLength characters',
      );
      return;
    }

    bool success = false;
    try {
      isSubmitting.value = true;
      await _dio.post('/job/create', data: {
        'orderId': order.id,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'elastics': items,
        if (needsReason) 'excessReason': reasonController.text.trim(),
        // 🪪 Actor attached so the backend records who created the job
        'actor': buildActorPayload(),
      });
      success = true;
      Get.snackbar(
        'Job Order Created',
        totalExcess > 0
            ? 'Preparatory programs generated · ${_fmt(totalExcess)} m over the order, yarn drawn from stock'
            : 'Preparatory (Warping & Covering) programs generated',
        backgroundColor: ErpColors.solidSuccess,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on DioException catch (e) {
      _reportFailure(e);
    } finally {
      isSubmitting.value = false;
      if (success) onSuccess?.call();
    }
  }

  /// The server refuses an over-plan for two reasons, and they need
  /// different things done about them: one wants a sentence typed, the
  /// other wants yarn bought. A single "Failed to create job order"
  /// tells the person on the floor neither.
  void _reportFailure(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['code']?.toString() : null;
    final message =
        (data is Map ? data['message']?.toString() : null) ?? 'Failed to create job order';

    switch (code) {
      case 'EXCESS_PLANNING_REASON_REQUIRED':
        // Only reachable if this screen's arithmetic and the server's
        // ever disagree — say so plainly rather than silently.
        Get.snackbar('Reason needed', message,
            backgroundColor: ErpColors.solidWarning,
            colorText: Colors.white,
            duration: const Duration(seconds: 6),
            snackPosition: SnackPosition.BOTTOM);
        break;

      case 'INSUFFICIENT_STOCK_FOR_EXCESS':
        // Unpacked in two steps rather than as
        //   data is Map ? data['details']?['shortfalls'] : null
        // because a null-aware index inside a conditional expression is a
        // parse ambiguity in Dart — `?[` after a `?` cannot be told from
        // the branch separator, and the file does not compile.
        final details    = data is Map ? data['details'] : null;
        final shortfalls = details is Map ? details['shortfalls'] : null;
        final named = (shortfalls is List && shortfalls.isNotEmpty)
            ? shortfalls
                .map((s) => '${s['name']} short by ${s['short']} kg')
                .join('\n')
            : message;
        Get.snackbar('Not enough yarn for the excess', named,
            backgroundColor: ErpColors.solidError,
            colorText: Colors.white,
            duration: const Duration(seconds: 8),
            snackPosition: SnackPosition.BOTTOM);
        break;

      default:
        Get.snackbar('Error', message,
            backgroundColor: ErpColors.solidError,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _warn(String message) {
    Get.snackbar(
      'Validation Error',
      message,
      backgroundColor: ErpColors.solidWarning,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void onClose() {
    for (final e in elasticInputs) {
      e.dispose();
    }
    reasonController.dispose();
    super.onClose();
  }
}
