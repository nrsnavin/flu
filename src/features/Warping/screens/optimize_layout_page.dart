import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/optimize_layout_controller.dart';

// Optimise warping layout — bin-packs warp-yarn ends into beams to cut
// beam count and yarn changeovers vs a naive one-yarn-per-beam layout.
// Review, then apply as the warping plan.
class OptimizeLayoutPage extends StatelessWidget {
  final String warpingId;
  const OptimizeLayoutPage({super.key, required this.warpingId});

  static const _capacities = [300, 600, 900, 1200];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(OptimizeLayoutController(warpingId), tag: warpingId);
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Optimise layout'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.metrics.value == null) {
          return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.metrics.value == null) {
          return Center(child: Text(c.errorMsg.value!, style: const TextStyle(color: ErpColors.textSecondary)));
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _capacitySelector(c),
            const SizedBox(height: 12),
            if (c.beams.isEmpty)
              _empty(c.message.value ?? 'Nothing to optimise.')
            else ...[
              _metricsGrid(c),
              const SizedBox(height: 12),
              ...c.beams.map(_beamCard),
              const SizedBox(height: 8),
              const Text(
                'Applying creates the warping plan — you can still edit beams before starting.',
                style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
              ),
              const SizedBox(height: 80),
            ],
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        if (c.beams.isEmpty) return const SizedBox.shrink();
        return SafeArea(
          minimum: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: c.isApplying.value ? null : () => _apply(context, c),
            icon: c.isApplying.value
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Apply as plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _apply(BuildContext context, OptimizeLayoutController c) async {
    final ok = await c.apply();
    if (ok) {
      Get.back(result: true);
      Get.snackbar('Applied', 'Optimised plan saved',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ErpColors.successGreen,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3));
    } else {
      Get.snackbar('Failed', 'Could not apply the plan',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ErpColors.errorRed,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2));
    }
  }

  Widget _capacitySelector(OptimizeLayoutController c) => Row(children: [
        const Text('Beam capacity',
            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Expanded(
          child: Obx(() => Wrap(
                spacing: 8,
                children: _capacities.map((cap) {
                  final sel = c.capacity.value == cap;
                  return ChoiceChip(
                    label: Text('$cap'),
                    selected: sel,
                    onSelected: (_) => c.setCapacity(cap),
                    selectedColor: ErpColors.accentBlue,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : ErpColors.textSecondary,
                        fontSize: 12, fontWeight: FontWeight.w700),
                    backgroundColor: ErpColors.bgSurface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: ErpColors.borderLight)),
                  );
                }).toList(),
              )),
        ),
      ]);

  Widget _metricsGrid(OptimizeLayoutController c) {
    final m = c.metrics.value!;
    return Row(children: [
      _tile('Beams', '${m.beamsUsed}', ErpColors.textPrimary),
      const SizedBox(width: 10),
      _tile('Saved', '${m.beamsSaved}', m.beamsSaved > 0 ? ErpColors.successGreen : ErpColors.textPrimary),
      const SizedBox(width: 10),
      _tile('Fill', '${m.fillRate}%', ErpColors.textPrimary),
      const SizedBox(width: 10),
      _tile('Changeovers', '${m.changeovers}', ErpColors.textPrimary),
    ]);
  }

  Widget _tile(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: ErpColors.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  Widget _beamCard(OptimBeam b) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Beam ${b.beamNo}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
            Text('${b.totalEnds} ends · ${b.fillPct}% full',
                style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (b.fillPct / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: ErpColors.bgMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(ErpColors.accentBlue),
            ),
          ),
          const SizedBox(height: 8),
          ...b.sections.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(
                    child: Text(s.warpYarnName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary)),
                  ),
                  Text('${s.ends} ends',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textSecondary)),
                ]),
              )),
        ]),
      );

  Widget _empty(String msg) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.grid_off_outlined, size: 40, color: ErpColors.textMuted),
            const SizedBox(height: 10),
            const Text('Nothing to optimise',
                style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            const SizedBox(height: 4),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
          ]),
        ),
      );
}
