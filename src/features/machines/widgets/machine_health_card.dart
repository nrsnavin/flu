import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/machine_controller.dart';

// Predicted-health card for a machine's detail page. Score + band are
// deterministic (from the backend); the AI diagnosis is fetched on demand.
class MachineHealthCard extends StatefulWidget {
  final String machineId;
  const MachineHealthCard({super.key, required this.machineId});

  @override
  State<MachineHealthCard> createState() => _MachineHealthCardState();
}

class _MachineHealthCardState extends State<MachineHealthCard> {
  Map<String, dynamic>? _health;
  bool _loading = true;
  bool _adviceOpen = false;
  bool _adviceLoading = false;
  String? _advice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await MachineApiService.predictiveHealth();
      _health = all.firstWhereOrNull((m) => '${m['machineId']}' == widget.machineId);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAdvice() async {
    setState(() {
      _adviceOpen = true;
      _adviceLoading = true;
    });
    try {
      _advice = await MachineApiService.healthAdvice(widget.machineId);
    } catch (_) {
      _advice = "Couldn't generate a diagnosis right now.";
    } finally {
      if (mounted) setState(() => _adviceLoading = false);
    }
  }

  Color _scoreColor(num s) =>
      s >= 75 ? ErpColors.successGreen : (s >= 50 ? ErpColors.warningAmber : ErpColors.errorRed);

  ({Color bg, Color fg, String label}) _band(String b) {
    switch (b) {
      case 'healthy':
        return (bg: ErpColors.statusCompletedBg, fg: ErpColors.successGreen, label: 'Healthy');
      case 'watch':
        return (bg: ErpColors.statusPartialBg, fg: ErpColors.warningAmber, label: 'Watch');
      default:
        return (bg: ErpColors.statusCancelledBg, fg: ErpColors.errorRed, label: 'At risk');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }
    final h = _health;
    if (h == null) return const SizedBox.shrink();
    final score = (h['score'] ?? 0) as num;
    final band = _band('${h['band'] ?? 'at_risk'}');
    final reasons = (h['reasons'] as List? ?? []);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.monitor_heart_outlined, size: 16, color: ErpColors.accentBlue),
            SizedBox(width: 6),
            Text('Predicted health', style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: band.bg, borderRadius: BorderRadius.circular(20)),
            child: Text(band.label, style: TextStyle(color: band.fg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$score', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: _scoreColor(score))),
          const Padding(
            padding: EdgeInsets.only(bottom: 6, left: 4),
            child: Text('/ 100', style: TextStyle(color: ErpColors.textMuted, fontSize: 12)),
          ),
        ]),
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...reasons.map((r) {
            final m = Map<String, dynamic>.from(r);
            final sev = '${m['severity'] ?? 'low'}';
            final dot = sev == 'high' ? ErpColors.errorRed : (sev == 'medium' ? ErpColors.warningAmber : ErpColors.textMuted);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(margin: const EdgeInsets.only(top: 5, right: 8), width: 7, height: 7,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                Expanded(
                  child: RichText(text: TextSpan(children: [
                    TextSpan(text: '${m['label'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: ErpColors.textPrimary, fontSize: 12)),
                    TextSpan(text: ' — ${m['detail'] ?? ''}',
                        style: const TextStyle(color: ErpColors.textSecondary, fontSize: 12)),
                  ])),
                ),
              ]),
            );
          }),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('No risk signals — running normally.', style: TextStyle(color: ErpColors.textMuted, fontSize: 12)),
          ),
        const SizedBox(height: 10),
        if (!_adviceOpen)
          OutlinedButton.icon(
            onPressed: _loadAdvice,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AI diagnosis'),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ErpColors.statusOpenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.auto_awesome, size: 13, color: ErpColors.accentBlue),
                SizedBox(width: 6),
                Text('AI DIAGNOSIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ErpColors.accentBlue)),
              ]),
              const SizedBox(height: 6),
              _adviceLoading
                  ? const Text('Analysing…', style: TextStyle(color: ErpColors.textMuted, fontSize: 12))
                  : Text(_advice ?? '', style: const TextStyle(color: ErpColors.textPrimary, fontSize: 12, height: 1.4)),
            ]),
          ),
      ]),
    );
  }
}
