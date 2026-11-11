import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../gst.dart';
import '../models/invoice_models.dart';

// The chips an invoice wears on its row and on its page — one place, so
// the two cannot tell different stories.

Widget invoiceChip(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );

/// "₹4,200.00 left · 3 days overdue", the web's Payment column.
({String text, bool late}) paymentLine(Invoice inv, [DateTime? now]) {
  switch (inv.paymentState) {
    case PaymentState.cancelled:
      return (text: 'Cancelled', late: false);
    case PaymentState.paid:
      return (text: 'Paid', late: false);
    case PaymentState.partPaid:
    case PaymentState.due:
      final left = inv.paymentState == PaymentState.partPaid ? 'left' : 'due';
      final d = inv.daysOverdue(now);
      final when = d > 0
          ? '$d day${d == 1 ? '' : 's'} overdue'
          : d == 0
              ? 'due today'
              : 'due in ${-d} day${d == -1 ? '' : 's'}';
      return (text: '${inr(inv.owed)} $left · $when', late: d > 0);
  }
}

class InvoiceChips extends StatelessWidget {
  const InvoiceChips({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final chips = <Widget>[];
    if (inv.isCancelled) {
      chips.add(invoiceChip('Cancelled', ErpColors.statusCancelledBg, ErpColors.statusCancelledText));
    } else {
      final pay = paymentLine(inv);
      chips.add(switch (inv.paymentState) {
        PaymentState.paid => invoiceChip('Paid', ErpColors.statusCompletedBg, ErpColors.statusCompletedText),
        _ => invoiceChip(
            pay.text,
            pay.late ? ErpColors.statusCancelledBg : ErpColors.statusOpenBg,
            pay.late ? ErpColors.errorRed : ErpColors.statusOpenText),
      });
      chips.add(inv.irnRegistered
          ? invoiceChip('IRN registered', ErpColors.statusCompletedBg, ErpColors.statusCompletedText)
          : inv.einvoiceStatus == 'cancelled'
              ? invoiceChip('IRN cancelled', ErpColors.bgMuted, ErpColors.textSecondary)
              : invoiceChip('IRN pending', ErpColors.statusPartialBg, ErpColors.statusPartialText));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

/// A label and a value on one line, the value right-aligned.
class InvoiceRow extends StatelessWidget {
  const InvoiceRow(this.label, this.value, {super.key, this.bold = false, this.color});

  final String label, value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: bold ? ErpColors.textPrimary : ErpColors.textSecondary,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: bold ? 14 : 12.5,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: color ?? ErpColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ],
        ),
      );
}
