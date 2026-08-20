import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/stock_count_controller.dart';
import '../models/stock_count.dart';
import 'stock_count_sheet_page.dart';

// ══════════════════════════════════════════════════════════════
//  STOCK COUNTS — THE LIST
//
//  Open sheets first and by default, because the only reason to reach
//  for this on a phone is that you are about to go and count something.
//  Posted ones are history and are a filter away.
// ══════════════════════════════════════════════════════════════

class StockCountListPageView extends StatefulWidget {
  const StockCountListPageView({super.key});

  @override
  State<StockCountListPageView> createState() => _StockCountListPageViewState();
}

class _StockCountListPageViewState extends State<StockCountListPageView> {
  late final StockCountListController c;

  @override
  void initState() {
    super.initState();
    Get.delete<StockCountListController>(force: true);
    c = Get.put(StockCountListController());
  }

  @override
  void dispose() {
    Get.delete<StockCountListController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Stock Counts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => c.fetch(),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value && c.counts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.errorMsg.value != null) {
                return _message(c.errorMsg.value!, onRetry: () => c.fetch());
              }
              if (c.counts.isEmpty) {
                return _message(
                  'No stock counts.\nA count is opened on the web, then walked here.',
                );
              }
              return RefreshIndicator(
                onRefresh: () => c.fetch(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: c.counts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CountCard(count: c.counts[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _filters() => Container(
        color: ErpColors.bgSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Obx(() => Row(
              children: [
                for (final f in const [
                  MapEntry<String?, String>(null, 'All'),
                  MapEntry<String?, String>('open', 'Open'),
                  MapEntry<String?, String>('posted', 'Posted'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.value),
                      selected: c.status.value == f.key,
                      onSelected: (_) => c.setStatus(f.key),
                    ),
                  ),
              ],
            )),
      );

  Widget _message(String text, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: ErpColors.textSecondary),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.count});

  final StockCount count;

  @override
  Widget build(BuildContext context) {
    final t = count.totals;
    final progress = t.lines == 0 ? 0.0 : t.counted / t.lines;

    return InkWell(
      onTap: () => Get.to(() => StockCountSheetPage(countId: count.id)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    count.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary,
                    ),
                  ),
                ),
                _StatusChip(status: count.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              count.frozenAt == null
                  ? 'Not frozen'
                  : 'Frozen ${DateFormat('dd MMM yyyy').format(count.frozenAt!)}',
              style: TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary),
            ),
            const SizedBox(height: 10),
            // How much walking is left, which is the only number
            // somebody standing in a store room wants from this screen.
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: ErpColors.bgBase,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${t.counted} of ${t.lines} counted'
              '${t.varied > 0 ? '  ·  ${t.varied} varied' : ''}'
              '${t.needingReason > 0 ? '  ·  ${t.needingReason} need a reason' : ''}',
              style: TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (status) {
      case 'posted':
        bg = ErpColors.statusOpenBg;
        fg = ErpColors.statusOpenText;
        break;
      case 'cancelled':
        bg = ErpColors.bgBase;
        fg = ErpColors.textMuted;
        break;
      default:
        bg = ErpColors.statusPartialBg;
        fg = ErpColors.accentBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
