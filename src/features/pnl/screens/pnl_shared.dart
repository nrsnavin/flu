import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  SHARED P&L PRESENTATION
//
//  One place for the two rules that matter on these screens:
//
//    • An unknown figure prints "—", never 0. A margin on zero revenue
//      is not 0% and not -100%; it is unknown, and printing a number
//      there is how a real loss gets lost among the noise.
//    • Money is coloured by sign, not by hope. Loss is red wherever it
//      appears, including in a total.
// ══════════════════════════════════════════════════════════════

final _moneyFmt = NumberFormat('#,##,###.##', 'en_IN');
final _qtyFmt = NumberFormat('#,##0.##', 'en_IN');

/// Rupees. Null is unknown and prints as a dash.
String money(double? v) => v == null ? '—' : '₹${_moneyFmt.format(v)}';

/// Rupees, rounded — for a list row where the paise are noise.
String moneyShort(double? v) {
  if (v == null) return '—';
  final a = v.abs();
  if (a >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
  if (a >= 100000) return '₹${(v / 100000).toStringAsFixed(2)} L';
  return '₹${NumberFormat('#,##,###', 'en_IN').format(v.round())}';
}

String qty(double? v) => v == null ? '—' : _qtyFmt.format(v);

/// A margin, or "—" when there is none to state.
String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

/// Green in profit, red in loss, muted when unknown. Deliberately not
/// amber-for-thin-margin: that would need a threshold nobody has agreed.
Color profitColor(double? profit) {
  if (profit == null) return ErpColors.textMuted;
  if (profit < 0) return ErpColors.errorRed;
  return ErpColors.successGreen;
}

Color statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'completed':
    case 'packing':
      return ErpColors.successGreen;
    case 'cancelled':
    case 'deleted':
      return ErpColors.errorRed;
    case 'pending':
    case 'open':
      return ErpColors.warningAmber;
    default:
      return ErpColors.accentBlue;
  }
}

String titleCase(String s) => s
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

// ── Small pieces ──────────────────────────────────────────────

class PnlStatusPill extends StatelessWidget {
  final String status;
  const PnlStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(titleCase(status),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

/// The margin badge. Unpriced reads "No price", not "0%", because those
/// are different facts and only one of them is bad news.
class PnlMarginBadge extends StatelessWidget {
  final double? marginPct;
  final double profit;
  final bool large;
  const PnlMarginBadge({
    super.key,
    required this.marginPct,
    required this.profit,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final known = marginPct != null;
    final color = known ? profitColor(profit) : ErpColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(large ? 8 : 10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        known ? pct(marginPct) : 'No price',
        style: TextStyle(
            color: color,
            fontSize: large ? 15 : 11,
            fontWeight: FontWeight.w900),
      ),
    );
  }
}

class PnlNote extends StatelessWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const PnlNote(this.msg, this.color, this.icon, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style:
                    TextStyle(color: color, fontSize: 11, height: 1.4)),
          ),
        ]),
      );
}

/// What is shown when the `/order-pnl` feature is withheld. Margin is
/// its own permission on purpose, so this is a normal answer rather
/// than an error — and it says who to ask instead of just refusing.
class PnlForbidden extends StatelessWidget {
  const PnlForbidden({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ErpColors.borderLight),
              ),
              child: Icon(Icons.lock_outline_rounded,
                  size: 32, color: ErpColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text('Margin is not shared with this account',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Seeing an order and seeing the profit on it are separate '
              'permissions. An admin can grant Order P&L under Users.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
            ),
          ]),
        ),
      );
}

/// A labelled figure. `value` is already formatted, so the caller
/// decides whether it is money, meters or a percentage.
class PnlFigure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final CrossAxisAlignment align;
  PnlFigure({
    super.key,
    required this.label,
    required this.value,
    Color? color,
    this.align = CrossAxisAlignment.center,
  }) : color = color ?? ErpColors.textPrimary;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: align,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: ErpColors.textMuted)),
        ],
      );
}
