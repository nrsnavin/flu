import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/add_po.dart' show POFormMode;
import '../controllers/low_stock_draft_controller.dart';
import '../services/theme.dart';
import 'add_po.dart';

/// Forecast-driven replenishment. Projects each material's stock from
/// on-hand − committed demand (Open orders) − run-rate × horizon, and
/// lists those about to breach their safety floor, grouped by supplier.
/// Each group has a "Draft PO" button that opens AddPOPage with the
/// supplier + suggested rows seeded, so the admin only reviews and submits.
class LowStockDraftPage extends StatelessWidget {
  const LowStockDraftPage({super.key});

  static const _horizons = [7, 14, 30, 60];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(LowStockDraftController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Replenishment forecast', style: ErpTextStyles.pageTitle),
            Text('Draft POs before you run out',
                style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: c.fetch,
          ),
        ],
      ),
      body: Obx(() {
        final hasAny = c.materials.isNotEmpty;
        if (c.loading.value && !hasAny) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null && !hasAny) {
          return _Error(message: c.errorMsg.value!, onRetry: c.fetch);
        }
        final groups = c.groupedBySupplier;
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _HorizonSelector(c: c),
              const SizedBox(height: 12),
              if (!hasAny)
                const _EmptyState()
              else ...[
                _StatsRow(c: c),
                if (c.aiSummary.value != null) ...[
                  const SizedBox(height: 12),
                  _AiSummaryCard(text: c.aiSummary.value!),
                ],
                const SizedBox(height: 12),
                for (final entry in groups.entries)
                  _SupplierGroupCard(
                    supplierId:   entry.key,
                    supplierName: entry.value.first.supplierName,
                    items:        entry.value,
                    onDraft: () => Get.to(() => AddPOPage(
                          mode: POFormMode.create,
                          seedData: c.seedDataFor(entry.key),
                        )),
                  ),
                if (c.skippedNoSupplier.value > 0) _SkippedNote(c: c),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _HorizonSelector extends StatelessWidget {
  final LowStockDraftController c;
  const _HorizonSelector({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(
          children: LowStockDraftPage._horizons.map((d) {
            final sel = c.horizon.value == d;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${d}d'),
                selected: sel,
                onSelected: (_) => c.setHorizon(d),
                selectedColor: ErpColors.accentBlue,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : ErpColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                backgroundColor: ErpColors.bgSurface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: ErpColors.borderLight)),
              ),
            );
          }).toList(),
        ));
  }
}

class _StatsRow extends StatelessWidget {
  final LowStockDraftController c;
  const _StatsRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _tile('To reorder', '${c.flaggedN.value}', ErpColors.warningAmber),
      const SizedBox(width: 10),
      _tile('Critical', '${c.criticalN.value}',
          c.criticalN.value > 0 ? ErpColors.errorRed : ErpColors.textPrimary),
      const SizedBox(width: 10),
      _tile('Est. spend', '₹${c.estSpend.value.toStringAsFixed(0)}', ErpColors.textPrimary),
    ]);
  }

  Widget _tile(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );
}

class _AiSummaryCard extends StatelessWidget {
  final String text;
  const _AiSummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: ErpColors.accentBlue, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, size: 14, color: ErpColors.accentBlue),
          SizedBox(width: 6),
          Text('AI PROCUREMENT SUMMARY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ErpColors.accentBlue)),
        ]),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary, height: 1.4)),
      ]),
    );
  }
}

class _SupplierGroupCard extends StatelessWidget {
  final String supplierId;
  final String supplierName;
  final List<LowStockMaterial> items;
  final VoidCallback onDraft;

  const _SupplierGroupCard({
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.onDraft,
  });

  @override
  Widget build(BuildContext context) {
    final totalValue = items.fold<double>(0, (s, m) => s + m.suggestedValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplierName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${items.length} material'
                        '${items.length == 1 ? '' : 's'}  ·  '
                        '₹${totalValue.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11, color: ErpColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onDraft,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Draft PO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          for (final m in items) _MaterialRow(m: m),
        ],
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  final LowStockMaterial m;
  const _MaterialRow({required this.m});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ErpColors.textPrimary)),
              ),
              if (m.daysToStockout != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (m.isCritical ? ErpColors.errorRed : ErpColors.warningAmber)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '~${m.daysToStockout!.toStringAsFixed(0)}d',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: m.isCritical ? ErpColors.errorRed : ErpColors.warningAmber),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${m.suggestedQty.toStringAsFixed(0)}${m.unit.isNotEmpty ? ' ${m.unit}' : ''}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: ErpColors.accentBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: m.stockPercent,
              minHeight: 4,
              backgroundColor: ErpColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                m.projectedStock < 0 ? ErpColors.errorRed : ErpColors.warningAmber,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'on-hand ${m.stock.toStringAsFixed(0)}'
            '${m.committedDemand > 0 ? '  ·  committed ${m.committedDemand.toStringAsFixed(0)}' : ''}'
            '  ·  proj ${m.projectedStock.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SkippedNote extends StatelessWidget {
  final LowStockDraftController c;
  const _SkippedNote({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.warningAmber.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.warningAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: ErpColors.warningAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${c.skippedNoSupplier.value} '
              'material${c.skippedNoSupplier.value == 1 ? '' : 's'} '
              'need reordering but have no default supplier set.',
              style: const TextStyle(fontSize: 12, color: ErpColors.warningAmber),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: ErpColors.successGreen),
            SizedBox(height: 12),
            Text('No replenishment needed',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            SizedBox(height: 4),
            Text('No material is projected to drop below its safety stock in this window.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: ErpColors.errorRed),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: ErpColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
