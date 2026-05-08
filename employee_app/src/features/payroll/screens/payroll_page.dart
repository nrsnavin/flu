import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../theme/erp_theme.dart';
import '../controllers/payroll_controller.dart';

class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PayrollController(), tag: 'payroll');
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('Payroll', style: ErpTextStyles.pageTitle),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        return RefreshIndicator(
          onRefresh: c.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _MonthSelector(c: c),
              const SizedBox(height: 12),
              if (c.slip.value == null)
                _NoSlipCard()
              else
                _SlipCard(slip: c.slip.value!),
              const SizedBox(height: 14),
              _AdvanceSection(c: c),
            ],
          ),
        );
      }),
    );
  }
}

// ── Month / Year selector ──────────────────────────────────────
class _MonthSelector extends StatelessWidget {
  final PayrollController c;
  const _MonthSelector({required this.c});

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM')
        .format(DateTime(c.selectedYear.value, c.selectedMonth.value));
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(children: [
        const Icon(Icons.event_outlined,
            color: ErpColors.accentBlue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$monthName ${c.selectedYear.value}',
              style: ErpTextStyles.cardTitle),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            int m = c.selectedMonth.value - 1;
            int y = c.selectedYear.value;
            if (m == 0) { m = 12; y -= 1; }
            c.changeMonth(y, m);
          },
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            int m = c.selectedMonth.value + 1;
            int y = c.selectedYear.value;
            if (m == 13) { m = 1; y += 1; }
            c.changeMonth(y, m);
          },
        ),
      ]),
    );
  }
}

// ── Slip card ──────────────────────────────────────────────────
class _SlipCard extends StatelessWidget {
  final Map<String, dynamic> slip;
  const _SlipCard({required this.slip});

  @override
  Widget build(BuildContext context) {
    final status = (slip['status']?.toString() ?? 'draft').toLowerCase();
    final gross  = (slip['grossPay']  as num?)?.toDouble() ?? 0;
    final net    = (slip['netPay']    as num?)?.toDouble() ?? 0;
    final deduct = (slip['totalDeductions'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined,
                color: ErpColors.accentLight, size: 18),
            const SizedBox(width: 6),
            const Text('PAY SLIP',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
            const Spacer(),
            _StatusChip(status),
          ]),
          const SizedBox(height: 14),
          Text('₹ ${net.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const Text('Net Pay',
              style:
                  TextStyle(color: ErpColors.textOnDarkSub, fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: [
            _MiniStat('Gross',     '₹ ${gross.toStringAsFixed(0)}'),
            const SizedBox(width: 10),
            _MiniStat('Deductions','₹ ${deduct.toStringAsFixed(0)}'),
          ]),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ErpColors.navyMid,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ErpTextStyles.kpiLabel),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'paid':
        bg = ErpColors.successGreen.withOpacity(0.18);
        fg = ErpColors.successGreen;
        break;
      case 'finalized':
        bg = ErpColors.warningAmber.withOpacity(0.18);
        fg = ErpColors.warningAmber;
        break;
      default:
        bg = ErpColors.accentBlue.withOpacity(0.22);
        fg = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
    );
  }
}

class _NoSlipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: const [
          Icon(Icons.pending_actions_outlined,
              size: 32, color: ErpColors.textMuted),
          SizedBox(height: 8),
          Text('Slip not generated yet',
              style: TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(
            'Your supervisor hasn\'t closed payroll for this month.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: ErpColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Advance requests ───────────────────────────────────────────
class _AdvanceSection extends StatelessWidget {
  final PayrollController c;
  const _AdvanceSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ErpDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                bottom: BorderSide(color: ErpColors.borderLight),
              ),
            ),
            child: Row(children: [
              const Icon(Icons.savings_outlined,
                  color: ErpColors.successGreen, size: 16),
              const SizedBox(width: 8),
              const Text('ADVANCE REQUESTS',
                  style: ErpTextStyles.sectionHeader),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openRequestSheet(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Request',
                    style:
                        TextStyle(fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  foregroundColor: ErpColors.accentBlue,
                ),
              ),
            ]),
          ),
          if (c.advances.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text('No advance requests yet.',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: c.advances.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1, color: ErpColors.borderLight,
              ),
              itemBuilder: (_, i) => _AdvanceTile(adv: c.advances[i]),
            ),
        ],
      ),
    );
  }

  void _openRequestSheet(BuildContext ctx) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: ErpColors.borderMid,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Request Advance',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Your supervisor will review this and decide which payroll month it deducts from.',
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d*')),
                ],
                decoration: ErpDecorations.formInput(
                  'Amount *',
                  hint: 'e.g. 5000',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12, top: 14),
                    child: Text('₹',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: ErpDecorations.formInput(
                  'Reason',
                  hint: 'e.g. medical / family event',
                ),
              ),
              const SizedBox(height: 18),
              Obx(() => SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ErpColors.successGreen,
                        disabledBackgroundColor:
                            ErpColors.successGreen.withOpacity(0.55),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: c.isRequesting.value
                          ? null
                          : () async {
                              final amt = double.tryParse(
                                      amountCtrl.text.trim()) ??
                                  0;
                              final ok = await c.requestAdvance(
                                amount: amt,
                                reason: reasonCtrl.text.trim(),
                              );
                              if (ok && Navigator.of(ctx).canPop()) {
                                Navigator.of(ctx).pop();
                              }
                            },
                      icon: c.isRequesting.value
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                      label: Text(
                        c.isRequesting.value ? 'Sending…' : 'Submit',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvanceTile extends StatelessWidget {
  final Map<String, dynamic> adv;
  const _AdvanceTile({required this.adv});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final raw = adv['createdAt']?.toString();
    String when = '—';
    if (raw != null) {
      try { when = fmt.format(DateTime.parse(raw).toLocal()); } catch (_) {}
    }
    final amount = (adv['amount'] as num?)?.toDouble() ?? 0;
    final status = (adv['status']?.toString() ?? 'pending').toLowerCase();
    final reason = adv['reason']?.toString() ?? '';

    Color statusColor;
    switch (status) {
      case 'approved': statusColor = ErpColors.successGreen; break;
      case 'rejected': statusColor = ErpColors.errorRed;     break;
      default:         statusColor = ErpColors.warningAmber;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.savings_outlined,
              color: statusColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('₹ ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              Text(when,
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11)),
              if (reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(reason,
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            border: Border.all(color: statusColor.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
