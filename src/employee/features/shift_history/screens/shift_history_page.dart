import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/shift_history_controller.dart';

class ShiftHistoryPage extends StatelessWidget {
  const ShiftHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmpShiftHistoryController(), tag: 'shift-history');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: AppBar(
          backgroundColor: ErpColors.navyDark,
          elevation: 0,
          title:
              const Text('Shift History', style: ErpTextStyles.pageTitle),
          bottom: const TabBar(
            indicatorColor: ErpColors.accentLight,
            labelColor: Colors.white,
            unselectedLabelColor: ErpColors.textOnDarkSub,
            labelStyle:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: 'Open'),
              Tab(text: 'Closed'),
            ],
          ),
        ),
        body: Obx(() {
          if (c.isLoading.value) {
            return const Center(
              child:
                  CircularProgressIndicator(color: ErpColors.accentBlue),
            );
          }
          if (c.errorMsg.value != null) {
            return _Center(c.errorMsg.value!, c.refreshAll);
          }
          return RefreshIndicator(
            onRefresh: c.refreshAll,
            child: TabBarView(children: [
              _ShiftList(items: c.openShifts,  emptyMsg: 'No open shifts'),
              _ShiftList(items: c.closedShifts, emptyMsg: 'No closed shifts yet'),
            ]),
          );
        }),
      ),
    );
  }
}

class _ShiftList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyMsg;
  const _ShiftList({required this.items, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.event_busy_outlined,
              size: 36, color: ErpColors.textMuted),
          const SizedBox(height: 8),
          Center(
            child: Text(emptyMsg,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 13)),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ShiftCard(s: items[i]),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final Map<String, dynamic> s;
  const _ShiftCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final dt = SafeJson.asLocalDateTime(s['date']);
    final when = dt == null ? '—' : fmt.format(dt);
    final shiftLabel = SafeJson.asString(s['shift'], '—');
    final status     = SafeJson.asString(s['status'], 'open').toLowerCase();

    // Pending entries carry the worker's value in the `submitted*`
    // fields. Show the submitted* numbers strictly for pending rows
    // so an admin-edit-in-flight can never appear as if it were the
    // worker's own submission. Closed rows show the final admin
    // numbers from `production` / `timer`.
    final isPending  = status == 'pending_verification';
    final isClosed   = status == 'closed';

    final productionRaw = isPending
        ? SafeJson.asNum(s['submittedProductionMeters'])
        : (SafeJson.asNum(s['production']) ??
           SafeJson.asNum(s['productionMeters']));
    final production = productionRaw?.toString() ?? '—';

    final timer = isPending
        ? SafeJson.asString(s['submittedTimer'], '—')
        : SafeJson.asString(s['timer'], '—');

    final feedback = isPending
        ? SafeJson.asString(s['submittedFeedback'])
        : SafeJson.asString(s['feedback']);

    // Pill colours per status. Pending = amber, closed = green, open = blue.
    final Color chipBg;
    final Color chipBorder;
    final Color chipText;
    final String chipLabel;
    if (isPending) {
      chipBg     = ErpColors.warningAmber.withValues(alpha: 0.12);
      chipBorder = ErpColors.warningAmber.withValues(alpha: 0.45);
      chipText   = ErpColors.warningAmber;
      chipLabel  = 'PENDING VERIFICATION';
    } else if (isClosed) {
      chipBg     = ErpColors.statusCompletedBg;
      chipBorder = ErpColors.statusCompletedBorder;
      chipText   = ErpColors.statusCompletedText;
      chipLabel  = 'CLOSED';
    } else {
      chipBg     = ErpColors.statusOpenBg;
      chipBorder = ErpColors.statusOpenBorder;
      chipText   = ErpColors.statusOpenText;
      chipLabel  = status.toUpperCase();
    }

    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipBg,
                border: Border.all(color: chipBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(chipLabel,
                  style: TextStyle(
                      color: chipText,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4)),
            ),
            const SizedBox(width: 8),
            Text(shiftLabel.toUpperCase(),
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(when,
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Stat('Production', '$production m'),
            const SizedBox(width: 12),
            _Stat('Timer', timer),
          ]),
          if (isPending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ErpColors.warningAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: ErpColors.warningAmber.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.hourglass_top_rounded,
                      color: ErpColors.warningAmber, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Submitted — waiting on admin verification. Numbers shown are what you entered; the admin may adjust before they’re finalised.',
                      style: TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((isClosed || isPending) && feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message_outlined,
                      color: ErpColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(feedback,
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
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

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _Center extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _Center(this.msg, this.onRetry);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: ErpColors.textMuted, size: 36),
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.accentBlue),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: ErpColors.accentBlue,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
