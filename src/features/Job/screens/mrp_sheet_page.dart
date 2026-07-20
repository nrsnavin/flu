import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/mrp_controller.dart';

// ════════════════════════════════════════════════════════════════
//  MATERIAL REQUIREMENT PROGRAM (MRP) — in-app view for one job
//
//  Mirrors the backend PDF: production-mode banner + toggle, elastics
//  to produce, the raw-material requirement table (with shortfall rows
//  highlighted), and the Prepared/Approved/Received signature block.
//  "Open PDF" fetches the signed PDF and opens it in the native viewer.
// ════════════════════════════════════════════════════════════════

class MrpSheetPage extends StatelessWidget {
  const MrpSheetPage({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<MrpController>(tag: jobId)
        ? Get.find<MrpController>(tag: jobId)
        : Get.put(MrpController(jobId), tag: jobId);
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        title: const Text('MRP Sheet', style: ErpTextStyles.pageTitle),
        actions: [
          Obx(() => IconButton(
                tooltip: 'Open PDF',
                onPressed: ctrl.pdfLoading.value ? null : ctrl.openPdf,
                icon: ctrl.pdfLoading.value
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf, color: Colors.white),
              )),
          IconButton(
            tooltip: 'Refresh',
            onPressed: ctrl.load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.data.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null && ctrl.data.value == null) {
          return _ErrorState(message: ctrl.errorMsg.value!, onRetry: ctrl.load);
        }
        final d = ctrl.data.value ?? const {};
        return RefreshIndicator(
          onRefresh: ctrl.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            children: [
              _MetaCard(d: d),
              const SizedBox(height: 14),
              _ModeCard(ctrl: ctrl),
              const SizedBox(height: 14),
              _ElasticsCard(elastics: ctrl.elastics),
              const SizedBox(height: 14),
              _MaterialsCard(
                materials: ctrl.materials,
                hasShortfall: ctrl.hasShortfall,
              ),
              const SizedBox(height: 14),
              const _SignatureBlock(),
            ],
          ),
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Obx(() => ElevatedButton.icon(
                onPressed: ctrl.pdfLoading.value ? null : ctrl.openPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: ctrl.pdfLoading.value
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(ctrl.pdfLoading.value
                    ? 'Opening…'
                    : 'Open MRP PDF (with signatures)'),
              )),
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.d});
  final Map<String, dynamic> d;
  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['Job Order #', d['jobOrderNo']?.toString() ?? '—'],
      ['Order #', d['orderNo']?.toString() ?? '—'],
      ['Customer', d['customerName']?.toString() ?? '—'],
      ['Date', d['dateLabel']?.toString() ?? '—'],
      ['Status', d['status']?.toString() ?? '—'],
    ];
    return _Card(
      title: 'Material Requirement Program',
      icon: Icons.description_outlined,
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(r[0],
                        style: const TextStyle(
                            color: ErpColors.textSecondary, fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(r[1],
                        style: const TextStyle(
                            color: ErpColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.ctrl});
  final MrpController ctrl;
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Production mode',
      icon: Icons.factory_outlined,
      child: Obx(() {
        final outsource = ctrl.isOutsource;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'In-house',
                    icon: Icons.home_work_outlined,
                    selected: !outsource,
                    onTap: ctrl.saving.value
                        ? null
                        : () => ctrl.setProductionMode('in_house'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeButton(
                    label: 'Outsource',
                    icon: Icons.local_shipping_outlined,
                    selected: outsource,
                    onTap: ctrl.saving.value
                        ? null
                        : () => _promptVendor(context, ctrl),
                  ),
                ),
              ],
            ),
            if (outsource) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.store_mall_directory_outlined,
                      size: 16, color: ErpColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ctrl.outsourceVendor.isEmpty
                          ? 'No vendor set'
                          : 'Vendor: ${ctrl.outsourceVendor}',
                      style: const TextStyle(
                          color: ErpColors.textPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: ctrl.saving.value
                        ? null
                        : () => _promptVendor(context, ctrl),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ],
            if (ctrl.saving.value)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        );
      }),
    );
  }

  Future<void> _promptVendor(BuildContext context, MrpController ctrl) async {
    final tec = TextEditingController(text: ctrl.outsourceVendor);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Outsource to vendor'),
        content: TextField(
          controller: tec,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Vendor / subcontractor name',
            hintText: 'e.g. Weavers United',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Set outsource'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ctrl.setProductionMode('outsource', vendor: tec.text.trim());
    }
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? ErpColors.accentBlue : ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? ErpColors.accentBlue : ErpColors.borderMid),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : ErpColors.textSecondary,
                size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : ErpColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ElasticsCard extends StatelessWidget {
  const _ElasticsCard({required this.elastics});
  final List<Map<String, dynamic>> elastics;
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Elastics to produce',
      icon: Icons.linear_scale,
      child: elastics.isEmpty
          ? const Text('No elastic lines on this job.',
              style: TextStyle(color: ErpColors.textSecondary))
          : Column(
              children: [
                for (final e in elastics)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(e['name']?.toString() ?? 'Unknown',
                              style: const TextStyle(
                                  color: ErpColors.textPrimary,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text('${_fmt(e['quantity'])} m',
                            style: const TextStyle(
                                color: ErpColors.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MaterialsCard extends StatelessWidget {
  const _MaterialsCard(
      {required this.materials, required this.hasShortfall});
  final List<Map<String, dynamic>> materials;
  final bool hasShortfall;
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Raw material requirement',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(flex: 5, child: _Th('Material')),
              Expanded(flex: 3, child: _Th('Req.', right: true)),
              Expanded(flex: 3, child: _Th('Stock', right: true)),
              Expanded(flex: 3, child: _Th('Short', right: true)),
            ],
          ),
          const Divider(color: ErpColors.borderLight),
          if (materials.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No BOM materials resolved for this job.',
                  style: TextStyle(color: ErpColors.textSecondary)),
            )
          else
            for (final m in materials) _MaterialRow(m: m),
          if (hasShortfall) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ErpColors.errorRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: ErpColors.errorRed),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Shortfall rows below the floor — raise a PO before production.',
                      style: TextStyle(color: ErpColors.errorRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.m});
  final Map<String, dynamic> m;
  @override
  Widget build(BuildContext context) {
    final short = ((m['shortfall'] as num?) ?? 0) > 0;
    final name = m['name']?.toString() ?? 'Unknown';
    final cat = m['category']?.toString() ?? '';
    return Container(
      color: short ? ErpColors.errorRed.withOpacity(0.06) : null,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontWeight: FontWeight.w500)),
                if (cat.isNotEmpty)
                  Text(cat,
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(flex: 3, child: _Td('${_fmt(m['requiredWeight'])} kg')),
          Expanded(flex: 3, child: _Td('${_fmt(m['inStock'])} kg')),
          Expanded(
            flex: 3,
            child: _Td(short ? '${_fmt(m['shortfall'])} kg' : '—',
                color: short ? ErpColors.errorRed : ErpColors.textSecondary,
                bold: short),
          ),
        ],
      ),
    );
  }
}

class _SignatureBlock extends StatelessWidget {
  const _SignatureBlock();
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Sign-off',
      icon: Icons.draw_outlined,
      child: Row(
        children: const [
          Expanded(child: _SignatureSlot(label: 'Prepared by')),
          SizedBox(width: 10),
          Expanded(child: _SignatureSlot(label: 'Approved by')),
          SizedBox(width: 10),
          Expanded(child: _SignatureSlot(label: 'Received by')),
        ],
      ),
    );
  }
}

class _SignatureSlot extends StatelessWidget {
  const _SignatureSlot({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Container(height: 1, color: ErpColors.borderMid),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.right = false});
  final String text;
  final bool right;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
          color: ErpColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700));
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.color, this.bold = false});
  final String text;
  final Color? color;
  final bool bold;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.right,
      style: TextStyle(
          color: color ?? ErpColors.textPrimary,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontSize: 12));
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, color: ErpColors.accentBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ],
          ),
          const Divider(color: ErpColors.borderLight),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: ErpColors.errorRed, size: 40),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ErpColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(dynamic n) {
  final v = (n is num) ? n : num.tryParse(n?.toString() ?? '') ?? 0;
  // Trim trailing zeros for weights like 24.0 → 24, 24.5 → 24.5.
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
