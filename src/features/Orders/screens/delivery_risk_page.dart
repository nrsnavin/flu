import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/delivery_risk_controller.dart';
import 'order_detail_page.dart';

// Proactive delivery-risk feed. Every in-flight order predicted to ship
// late, with a ready-to-send customer update. Nothing is sent
// automatically — the admin copies each message and sends it.
class DeliveryRiskPage extends StatelessWidget {
  const DeliveryRiskPage({super.key});

  static final _d = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DeliveryRiskController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Delivery-risk alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: c.fetch,
          ),
        ],
      ),
      body: Obx(() {
        if (c.isLoading.value && c.risks.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.risks.isEmpty) {
          return Center(child: Text(c.errorMsg.value!, style: const TextStyle(color: ErpColors.textSecondary)));
        }
        if (c.risks.isEmpty) {
          return _empty();
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _banner(c.risks.length),
              const SizedBox(height: 12),
              ...c.risks.map(_riskCard),
              const SizedBox(height: 8),
              const Text(
                'You review and send each message — nothing goes out automatically.',
                style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.check_circle_outline, size: 48, color: ErpColors.successGreen),
          SizedBox(height: 12),
          Center(
            child: Text('No orders predicted late.',
                style: TextStyle(color: ErpColors.textSecondary, fontSize: 14)),
          ),
        ],
      );

  Widget _banner(int n) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.statusCancelledBg,
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: ErpColors.errorRed, width: 4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: ErpColors.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$n order${n == 1 ? '' : 's'} predicted late — draft customer updates ready',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ErpColors.errorRed),
            ),
          ),
        ]),
      );

  Widget _riskCard(DeliveryRisk r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Order #${r.orderNo}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ErpColors.textPrimary)),
              Text(r.customerName, style: const TextStyle(fontSize: 13, color: ErpColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ErpColors.statusCancelledBg, borderRadius: BorderRadius.circular(20)),
                child: Text('${r.lateWorkingDays}d late',
                    style: const TextStyle(color: ErpColors.errorRed, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'promised ${_d.format(r.promised ?? DateTime.now())} → predicted ${r.expectedDate == null ? '—' : _d.format(r.expectedDate!)}',
          style: const TextStyle(fontSize: 11, color: ErpColors.textMuted),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: ErpColors.bgBase, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (r.aiDrafted)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: ErpColors.statusOpenBg, borderRadius: BorderRadius.circular(4)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, size: 11, color: ErpColors.accentBlue),
                  SizedBox(width: 4),
                  Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ErpColors.accentBlue)),
                ]),
              ),
            Text(r.draft, style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: r.draft));
              Get.snackbar('Copied', 'Message copied to clipboard',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: ErpColors.textPrimary,
                  colorText: ErpColors.textOnDark,
                  margin: const EdgeInsets.all(12),
                  duration: const Duration(seconds: 2));
            },
            icon: const Icon(Icons.copy, size: 15),
            label: const Text('Copy message'),
          ),
          const SizedBox(width: 8),
          if (r.whatsappNumber != null)
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: r.whatsappNumber!));
                Get.snackbar('Copied', 'Customer number copied',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: ErpColors.textPrimary,
                    colorText: ErpColors.textOnDark,
                    margin: const EdgeInsets.all(12),
                    duration: const Duration(seconds: 2));
              },
              icon: const Icon(Icons.phone_outlined, size: 15),
              label: const Text('Copy no.'),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Get.to(() => OrderDetailPage(), arguments: {'orderId': r.orderId}),
            child: const Text('Order'),
          ),
        ]),
      ]),
    );
  }
}
