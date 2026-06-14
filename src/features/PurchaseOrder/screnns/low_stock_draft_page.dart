import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/add_po.dart' show POFormMode;
import '../controllers/low_stock_draft_controller.dart';
import '../services/theme.dart';
import 'add_po.dart';

/// Picker that lists materials currently at or below their min-stock
/// floor, grouped by supplier. Each group has a "Draft PO" button
/// that opens AddPOPage with the supplier + suggested rows already
/// seeded, so the admin only has to review and submit.
class LowStockDraftPage extends StatelessWidget {
  const LowStockDraftPage({super.key});

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
            Text('Draft POs', style: ErpTextStyles.pageTitle),
            Text('Materials below min stock',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
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
        if (c.loading.value && c.materials.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null && c.materials.isEmpty) {
          return _Error(message: c.errorMsg.value!, onRetry: c.fetch);
        }
        if (c.materials.isEmpty) {
          return const _EmptyState();
        }
        final groups = c.groupedBySupplier;
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
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
          ),
        );
      }),
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
    final totalValue =
        items.fold<double>(0, (s, m) => s + m.suggestedValue);
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
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
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
                            fontSize: 11,
                            color: ErpColors.textSecondary),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${m.suggestedQty.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.accentBlue),
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
                m.stock <= 0 ? ErpColors.errorRed : ErpColors.warningAmber,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stock ${m.stock.toStringAsFixed(0)}  /  min ${m.minStock.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 11, color: ErpColors.textSecondary),
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
          const Icon(Icons.info_outline_rounded,
              size: 14, color: ErpColors.warningAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${c.skippedNoSupplier.value} low-stock '
              'material${c.skippedNoSupplier.value == 1 ? '' : 's'} '
              'skipped — no default supplier set.',
              style: const TextStyle(
                  fontSize: 12, color: ErpColors.warningAmber),
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
            Icon(Icons.check_circle_outline_rounded,
                size: 48, color: ErpColors.successGreen),
            SizedBox(height: 12),
            Text('All materials are above min stock',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            SizedBox(height: 4),
            Text('Nothing to draft right now.',
                style: TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
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
            const Icon(Icons.error_outline_rounded,
                size: 40, color: ErpColors.errorRed),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: ErpColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
