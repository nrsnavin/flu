import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/leave_controller.dart';

class LeavePage extends StatelessWidget {
  const LeavePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmpLeaveController(), tag: 'leave');
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: AppBar(
          backgroundColor: ErpColors.navyDark,
          elevation: 0,
          title: const Text('Leave', style: ErpTextStyles.pageTitle),
          bottom: const TabBar(
            indicatorColor: ErpColors.accentLight,
            labelColor: Colors.white,
            unselectedLabelColor: ErpColors.textOnDarkSub,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: ErpColors.accentBlue,
          onPressed: () => _openRequestSheet(context, c),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Request',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        body: Obx(() {
          if (c.isLoading.value) {
            return const Center(
                child: CircularProgressIndicator(color: ErpColors.accentBlue));
          }
          if (c.errorMsg.value != null) {
            return _Error(msg: c.errorMsg.value!, onRetry: c.fetchAll);
          }
          return RefreshIndicator(
            onRefresh: c.fetchAll,
            child: TabBarView(children: [
              _LeaveList(items: c.pending,
                  emptyMsg: 'No pending requests',
                  cancellable: true,
                  onCancel: c.cancel),
              _LeaveList(items: c.approved,
                  emptyMsg: 'No approved leave yet',
                  cancellable: false),
              _LeaveList(items: c.rejected,
                  emptyMsg: 'No rejected requests',
                  cancellable: false),
            ]),
          );
        }),
      ),
    );
  }

  void _openRequestSheet(BuildContext ctx, EmpLeaveController c) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _RequestSheet(c: c),
      ),
    );
  }
}

// ── Tab list ───────────────────────────────────────────────────
class _LeaveList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyMsg;
  final bool cancellable;
  final Future<bool> Function(String id)? onCancel;
  const _LeaveList({
    required this.items,
    required this.emptyMsg,
    required this.cancellable,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.event_busy_outlined,
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _LeaveCard(
        l: items[i],
        cancellable: cancellable,
        onCancel: onCancel,
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> l;
  final bool cancellable;
  final Future<bool> Function(String id)? onCancel;
  const _LeaveCard({
    required this.l,
    required this.cancellable,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final dt = SafeJson.asLocalDateTime(l['date']);
    final when = dt == null ? '—' : fmt.format(dt);
    final shift     = SafeJson.asString(l['shift'], '—');
    final leaveType = SafeJson.asString(l['leaveType'], '—');
    final reason    = SafeJson.asString(l['reason']);
    final status    = SafeJson.asString(l['status'], 'pending').toLowerCase();
    final notes     = SafeJson.asString(l['reviewNotes']);

    Color statusColor;
    switch (status) {
      case 'approved': statusColor = ErpColors.successGreen; break;
      case 'rejected': statusColor = ErpColors.errorRed;     break;
      default:         statusColor = ErpColors.warningAmber;
    }

    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Text(leaveType.toUpperCase(),
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(when,
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time_rounded,
                size: 13, color: ErpColors.textMuted),
            const SizedBox(width: 4),
            Text('Shift: $shift',
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          ]),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Reason: $reason',
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Reviewer note: $notes',
                style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
          // Only render the cancel button when we actually have an
          // id to send to DELETE — otherwise the tap produces a 404.
          if (cancellable &&
              onCancel != null &&
              SafeJson.asString(l['id'] ?? l['_id']).isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () =>
                    onCancel!(SafeJson.asString(l['id'] ?? l['_id'])),
                icon: const Icon(Icons.close_rounded,
                    size: 14, color: ErpColors.errorRed),
                label: const Text('Cancel',
                    style: TextStyle(
                        color: ErpColors.errorRed,
                        fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ErpColors.errorRed),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Request bottom sheet ───────────────────────────────────────
class _RequestSheet extends StatefulWidget {
  final EmpLeaveController c;
  const _RequestSheet({required this.c});
  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  DateTime? _date;
  String _shift     = 'DAY';
  String _leaveType = 'casual';
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null
        ? 'Pick a date'
        : DateFormat('dd MMM yyyy').format(_date!);
    return Container(
      decoration: const BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
          const Text('Request Leave',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Your supervisor will be notified to approve or reject this.',
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Date
          InkWell(
            onTap: () async {
              final today = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? today.add(const Duration(days: 1)),
                firstDate: today,
                lastDate: DateTime(today.year + 1, 12, 31),
              );
              if (picked != null && mounted) {
                setState(() => _date = picked);
              }
            },
            child: InputDecorator(
              decoration: ErpDecorations.formInput(
                'Date *',
                prefix: const Icon(Icons.event_outlined,
                    size: 18, color: ErpColors.textMuted),
              ),
              child: Text(dateLabel,
                  style: const TextStyle(
                      color: ErpColors.textPrimary, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 10),

          // Shift dropdown
          DropdownButtonFormField<String>(
            value: _shift,
            decoration: ErpDecorations.formInput('Shift *'),
            items: const [
              DropdownMenuItem(value: 'DAY',   child: Text('Day')),
              DropdownMenuItem(value: 'NIGHT', child: Text('Night')),
              DropdownMenuItem(value: 'BOTH',  child: Text('Both (full day)')),
            ],
            onChanged: (v) => setState(() => _shift = v ?? 'DAY'),
          ),
          const SizedBox(height: 10),

          // Leave type. The three the server takes: "Earned" was offered
          // here too, and choosing it was refused every time.
          DropdownButtonFormField<String>(
            value: _leaveType,
            decoration: ErpDecorations.formInput('Leave Type *'),
            items: const [
              DropdownMenuItem(value: 'casual', child: Text('Casual')),
              DropdownMenuItem(value: 'sick',   child: Text('Sick')),
              DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
            ],
            onChanged: (v) => setState(() => _leaveType = v ?? 'casual'),
          ),
          const SizedBox(height: 10),

          // Reason
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: ErpDecorations.formInput(
              'Reason *',
              hint: 'e.g. medical / family event',
            ),
          ),
          const SizedBox(height: 18),

          Obx(() => SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    disabledBackgroundColor:
                        ErpColors.accentBlue.withValues(alpha: 0.55),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: widget.c.isSubmitting.value
                      ? null
                      : () async {
                          if (_date == null) {
                            Get.snackbar('Validation', 'Pick a date',
                                backgroundColor: ErpColors.errorRed,
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM);
                            return;
                          }
                          final ok = await widget.c.submit(
                            date: _date!,
                            shift: _shift,
                            leaveType: _leaveType,
                            reason: _reasonCtrl.text,
                          );
                          if (ok && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                  icon: widget.c.isSubmitting.value
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                  label: Text(
                    widget.c.isSubmitting.value ? 'Sending…' : 'Submit',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _Error({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
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
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
