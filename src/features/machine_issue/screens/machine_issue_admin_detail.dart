import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/machine_issue_admin_controller.dart';

// ══════════════════════════════════════════════════════════════
//  MACHINE ISSUE ADMIN DETAIL PAGE
//  Open from MachineIssueAdminListPage with arguments: the issue id.
//  Shows the worker's submission + a status-update action that
//  posts to PUT /api/v2/machine-issue/:id/status.
// ══════════════════════════════════════════════════════════════
class MachineIssueAdminDetailPage extends StatefulWidget {
  const MachineIssueAdminDetailPage({super.key});

  @override
  State<MachineIssueAdminDetailPage> createState() =>
      _MachineIssueAdminDetailPageState();
}

class _MachineIssueAdminDetailPageState
    extends State<MachineIssueAdminDetailPage> {
  late final MachineIssueAdminController c;
  String _id = '';

  @override
  void initState() {
    super.initState();
    c = Get.isRegistered<MachineIssueAdminController>()
        ? Get.find<MachineIssueAdminController>()
        : Get.put(MachineIssueAdminController());
    final arg = Get.arguments;
    _id = (arg is String && arg.isNotEmpty) ? arg : '';
    if (_id.isNotEmpty) {
      c.fetchDetail(_id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_id.isEmpty) {
      return Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: const ErpAppBar(title: 'Machine Issue'),
        body: Center(
          child: Text('No issue id supplied',
              style: TextStyle(color: ErpColors.textSecondary)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: 'Machine Issue', subtitle: 'Detail'),
      body: Obx(() {
        final issue = c.selected.value;
        if (issue == null) {
          return Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }
        return _Body(c: c, issue: issue);
      }),
    );
  }
}

class _Body extends StatelessWidget {
  final MachineIssueAdminController c;
  final Map<String, dynamic> issue;
  const _Body({required this.c, required this.issue});

  @override
  Widget build(BuildContext context) {
    final title       = issue['title']?.toString() ?? '—';
    final description = issue['description']?.toString() ?? '';
    final severity    = issue['severity']?.toString() ?? 'medium';
    final status      = issue['status']?.toString() ?? 'open';
    final notes       = issue['resolutionNotes']?.toString() ?? '';

    final machine  = issue['machine']  is Map ? issue['machine']  as Map : const {};
    final employee = issue['employee'] is Map ? issue['employee'] as Map : const {};
    final resolver = issue['resolvedBy'] is Map ? issue['resolvedBy'] as Map : const {};

    final machineId = machine['ID']?.toString() ?? '—';
    final empName   = employee['name']?.toString() ?? '—';
    final dept      = employee['department']?.toString() ?? '';

    String when(String? raw) {
      if (raw == null) return '—';
      final dt = DateTime.tryParse(raw);
      if (dt == null) return '—';
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        // ── Header card ─────────────────────────────────────
        Container(
          decoration: ErpDecorations.card,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                ),
                _SeverityChip(severity: severity),
              ]),
              const SizedBox(height: 10),
              _kv(Icons.precision_manufacturing_outlined,
                  'Machine', machineId),
              _kv(Icons.person_outline, 'Reported by',
                  dept.isEmpty ? empName : '$empName · $dept'),
              _kv(Icons.calendar_today_outlined, 'Filed',
                  when(issue['createdAt']?.toString())),
              _kv(Icons.flag_circle_outlined, 'Status', status.toUpperCase()),
              if (issue['resolvedAt'] != null)
                _kv(Icons.task_alt_outlined, 'Resolved',
                    when(issue['resolvedAt']?.toString())),
              if (resolver['name'] != null)
                _kv(Icons.engineering_outlined, 'Resolved by',
                    resolver['name']?.toString() ?? '—'),
            ],
          ),
        ),

        // ── Description card ────────────────────────────────
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: ErpDecorations.card,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DESCRIPTION',
                    style: TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(description,
                    style: TextStyle(
                        color: ErpColors.textPrimary, fontSize: 13)),
              ],
            ),
          ),
        ],

        // ── Resolution notes card ───────────────────────────
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: ErpDecorations.card,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESOLUTION NOTES',
                    style: TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(notes,
                    style: TextStyle(
                        color: ErpColors.textPrimary, fontSize: 13)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Action ──────────────────────────────────────────
        if (status != 'resolved' && status != 'rejected')
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => _showStatusSheet(context, c, issue),
            icon: const Icon(Icons.update, color: Colors.white, size: 18),
            label: const Text('Update Status',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Row(children: [
              Icon(
                status == 'resolved'
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: status == 'resolved'
                    ? ErpColors.successGreen
                    : ErpColors.errorRed,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status == 'resolved'
                      ? 'Issue closed as resolved'
                      : 'Issue rejected',
                  style: TextStyle(
                      color: ErpColors.textPrimary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _kv(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 12, color: ErpColors.textMuted),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  color: ErpColors.textMuted, fontSize: 11)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (severity) {
      'critical' => (Color(0xFFFEE2E2), ErpColors.errorRed, 'CRITICAL'),
      'high'     => (Color(0xFFFEF3C7), ErpColors.warningAmber, 'HIGH'),
      'medium'   => (ErpColors.statusOpenBg, ErpColors.statusOpenText, 'MEDIUM'),
      _          => (ErpColors.bgMuted, ErpColors.textMuted, 'LOW'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4)),
    );
  }
}

void _showStatusSheet(
  BuildContext context,
  MachineIssueAdminController c,
  Map<String, dynamic> issue,
) {
  final current = issue['status']?.toString() ?? 'open';
  final notesCtrl = TextEditingController(
      text: issue['resolutionNotes']?.toString() ?? '');
  final id = issue['_id']?.toString() ?? '';
  String picked = current;

  const transitions = ['acknowledged', 'in_progress', 'resolved', 'rejected'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return StatefulBuilder(builder: (sheetCtx, setSheetState) {
        final needsNotes = picked == 'resolved' || picked == 'rejected';
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ErpColors.borderMid,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Update Status',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: transitions.map((s) {
                    final selected = picked == s;
                    return ChoiceChip(
                      label: Text(s.replaceAll('_', ' ').toUpperCase()),
                      selected: selected,
                      selectedColor: ErpColors.accentBlue,
                      backgroundColor: ErpColors.bgMuted,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : ErpColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      onSelected: (_) =>
                          setSheetState(() => picked = s),
                    );
                  }).toList(),
                ),
                if (needsNotes) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: ErpDecorations.formInput(
                      'Resolution notes *',
                      hint: needsNotes
                          ? 'Required when resolving or rejecting'
                          : 'Optional notes',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ErpColors.accentBlue,
                          disabledBackgroundColor:
                              ErpColors.accentBlue.withValues(alpha: 0.55),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: c.updating.value
                            ? null
                            : () async {
                                if (needsNotes &&
                                    notesCtrl.text.trim().isEmpty) {
                                  Get.snackbar(
                                    'Validation',
                                    'Add a resolution note before closing',
                                    backgroundColor:
                                        ErpColors.solidError,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return;
                                }
                                final ok = await c.updateStatus(
                                  id,
                                  nextStatus: picked,
                                  resolutionNotes:
                                      notesCtrl.text.trim(),
                                );
                                if (ok && Navigator.of(sheetCtx).canPop()) {
                                  Navigator.of(sheetCtx).pop();
                                  Get.snackbar(
                                    'Updated',
                                    'Issue marked as $picked',
                                    backgroundColor:
                                        ErpColors.solidSuccess,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                }
                              },
                        icon: c.updating.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18),
                        label: Text(
                          c.updating.value ? 'Saving…' : 'Confirm',
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
        );
      });
    },
  );
}
