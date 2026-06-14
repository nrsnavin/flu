import 'package:get/get.dart';

import '../../PurchaseOrder/controllers/add_po.dart' show POFormMode;
import '../../PurchaseOrder/controllers/low_stock_draft_controller.dart';
import '../../PurchaseOrder/screnns/add_po.dart';
import '../../PurchaseOrder/screnns/low_stock_draft_page.dart';

/// Lightweight namespace for the closures used by D2 inline-action
/// buttons on advisor cards. Keeping them here avoids the
/// `ai_advisor` service file growing imports against feature UI
/// — the rule methods just point a card at one of these helpers.
class AdvisorActions {
  AdvisorActions._();

  /// Used by the low-stock and projected-stockout cards. Loads the
  /// draft picker controller, then short-circuits to AddPO when
  /// there's only one supplier worth drafting for; falls back to
  /// the full picker page otherwise. The fetch is awaited so the
  /// caller can show a spinner while the call runs.
  static Future<void> draftLowStockPo() async {
    final c = Get.put(LowStockDraftController());
    await c.fetch();
    final groups = c.groupedBySupplier;
    if (groups.length == 1) {
      final supplierId = groups.keys.first;
      Get.to(() => AddPOPage(
            mode: POFormMode.create,
            seedData: c.seedDataFor(supplierId),
          ));
    } else {
      Get.to(() => const LowStockDraftPage());
    }
  }
}
