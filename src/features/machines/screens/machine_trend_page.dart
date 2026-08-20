import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/mini_bar_chart.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/service_analytics_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ONE MACHINE: WHAT IT MADE, WHAT IT COST
//
//  Two charts over the SAME months, stacked so they read against each
//  other. That pairing is the whole point — spend on its own says a
//  machine is expensive, output on its own says it is busy, and only
//  the two together say whether the money is buying anything.
//
//  They are deliberately not overlaid on one axis. Rupees and metres
//  share no scale, and a twin-axis chart on a phone invites exactly
//  the comparison that is not valid — that the lines "crossing" means
//  something. Stacked, each is read on its own and the eye does the
//  honest comparison of shape against shape.
// ══════════════════════════════════════════════════════════════

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _num = NumberFormat.decimalPattern('en_IN');

class MachineTrendPage extends StatefulWidget {
  const MachineTrendPage({
    super.key,
    required this.machineId,
    required this.machineCode,
  });

  final String machineId;
  final String machineCode;

  @override
  State<MachineTrendPage> createState() => _MachineTrendPageState();
}

class _MachineTrendPageState extends State<MachineTrendPage> {
  late final MachineTrendController c;
  final _tag = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    c = Get.put(MachineTrendController(widget.machineId), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<MachineTrendController>(tag: _tag, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: Text('Machine ${widget.machineCode}'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.spend.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ErpColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: c.fetch, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }

        final s = c.spend.value;
        final p = c.production.value;

        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _card(
                'Output',
                p == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_num.format(p.totalMeters.round())} m',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textPrimary)),
                          const SizedBox(height: 10),
                          MiniBarChart(
                            bars: [
                              for (final x in p.series)
                                MiniBar(label: x.shortMonth, value: x.meters),
                            ],
                            barColor: ErpColors.accentBlue,
                            format: (v) => '${_num.format(v.round())} m',
                            emptyLabel: 'No output recorded in this window.',
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              _card(
                'Service cost',
                s == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_inr.format(s.total),
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textPrimary)),
                          Text('${s.services} services',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: ErpColors.textSecondary)),
                          const SizedBox(height: 10),
                          MiniBarChart(
                            bars: [
                              for (final x in s.series)
                                MiniBar(label: x.shortMonth, value: x.total),
                            ],
                            barColor: ErpColors.statusOpenText,
                            format: _inr.format,
                            emptyLabel: 'Nothing spent on this machine.',
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _card(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}
