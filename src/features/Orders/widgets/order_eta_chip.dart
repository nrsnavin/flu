import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/order_list_eta_controller.dart';

/// Compact per-row ETA chip rendered in the order list. Shows the
/// predicted completion date for in-flight orders, color-coded by
/// on-time vs late, with a tiny "learned" badge when the prediction
/// drew on the per-(elastic, machine) posterior for any pair.
class OrderEtaChip extends StatelessWidget {
  final OrderEtaSummary summary;
  const OrderEtaChip({super.key, required this.summary});

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final tone = summary.late ? ErpColors.errorRed : ErpColors.successGreen;
    // Posterior badge fires as soon as any pair on this order is
    // posterior-backed — even one pair means the ML layer contributed.
    final isLearned = summary.posteriorElastics > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            summary.late
                ? Icons.warning_amber_rounded
                : Icons.event_available_rounded,
            size: 11,
            color: tone,
          ),
          const SizedBox(width: 4),
          Text(
            'ETA ${_fmt(summary.expectedDate)}',
            style: TextStyle(
              color: tone,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          if (summary.late) ...[
            const SizedBox(width: 4),
            Text(
              '· ${summary.lateWorkingDays}d late',
              style: TextStyle(
                color: tone,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (isLearned) ...[
            const SizedBox(width: 5),
            Icon(
              Icons.psychology_rounded,
              size: 10,
              color: ErpColors.accentBlue,
            ),
          ],
        ],
      ),
    );
  }
}
