import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/machine_issue_admin_controller.dart';
import 'machine_issue_admin_detail.dart';
import 'machine_issue_report_screen.dart';

// ══════════════════════════════════════════════════════════════
//  MACHINE ISSUE ADMIN LIST PAGE
//  Workers file machine issues from the worker app; admins triage,
//  acknowledge, mark in-progress, and resolve them here.
// ══════════════════════════════════════════════════════════════
class MachineIssueAdminListPage extends StatelessWidget {
  const MachineIssueAdminListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(MachineIssueAdminController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Machine Issues',
        subtitle: 'Triage and report breakdowns',
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        onPressed: () => Get.to(() => const MachineIssueReportScreen()),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Report',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _Filters(c: c),
          Expanded(
            child: Obx(() {
              if (c.loading.value && c.items.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(
                    color: ErpColors.accentBlue,
                  ),
                );
              }
              if (c.errorMsg.value != null && c.items.isEmpty) {
                return _Empty(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load issues',
                  subtitle: c.errorMsg.value!,
                  cta: 'Retry',
                  onTap: c.fetch,
                );
              }
              if (c.items.isEmpty) {
                return _Empty(
                  icon: Icons.build_circle_outlined,
                  title: 'No issues in this queue',
                  subtitle:
                      'Workers report from the worker portal — or tap Report to raise one yourself.',
                  cta: 'Refresh',
                  onTap: c.fetch,
                );
              }
              return RefreshIndicator(
                onRefresh: c.fetch,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  itemCount: c.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _IssueCard(c: c, item: c.items[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final MachineIssueAdminController c;
  const _Filters({required this.c});

  static const _labels = {
    'all':          'All',
    'open':         'Open',
    'acknowledged': 'Ack',
    'in_progress':  'In Progress',
    'resolved':     'Resolved',
    'rejected':     'Rejected',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MachineIssueAdminController.statuses.map((s) {
                final selected = c.status.value == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_labels[s] ?? s),
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
                    onSelected: (_) => c.status.value = s,
                  ),
                );
              }).toList(),
            ),
          )),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final MachineIssueAdminController c;
  final Map<String, dynamic> item;
  const _IssueCard({required this.c, required this.item});

  @override
  Widget build(BuildContext context) {
    final title    = item['title']?.toString() ?? '—';
    final severity = item['severity']?.toString() ?? 'medium';
    final status   = item['status']?.toString() ?? 'open';
    final machine  = item['machine'] is Map ? item['machine'] as Map : const {};
    final employee = item['employee'] is Map ? item['employee'] as Map : const {};
    final machineId = machine['ID']?.toString() ?? '—';
    final empName   = employee['name']?.toString() ?? '—';
    final dept      = employee['department']?.toString() ?? '';

    String when = '';
    final created = item['createdAt']?.toString();
    if (created != null) {
      final dt = DateTime.tryParse(created);
      if (dt != null) {
        when = DateFormat('dd MMM, hh:mm a').format(dt.toLocal());
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Get.to(
        () => const MachineIssueAdminDetailPage(),
        arguments: item['_id']?.toString(),
      ),
      child: Container(
        decoration: ErpDecorations.card,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _SeverityDot(severity: severity),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusPill(status: status),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.precision_manufacturing_outlined,
                  size: 12, color: ErpColors.textMuted),
              const SizedBox(width: 4),
              Text(machineId,
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 11)),
              const SizedBox(width: 12),
              Icon(Icons.person_outline,
                  size: 12, color: ErpColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  dept.isEmpty ? empName : '$empName · $dept',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 11),
                ),
              ),
            ]),
            if (when.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(when,
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' => ErpColors.errorRed,
      'high'     => ErpColors.warningAmber,
      'medium'   => ErpColors.accentBlue,
      _          => ErpColors.textMuted,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'open'         => (ErpColors.statusOpenBg, ErpColors.statusOpenText, 'OPEN'),
      'acknowledged' => (Color(0xFFFEF3C7), Color(0xFFB45309), 'ACK'),
      'in_progress'  => (Color(0xFFFCE7F3), Color(0xFFBE185D), 'IN PROGRESS'),
      'resolved'     => (Color(0xFFDCFCE7), Color(0xFF15803D), 'RESOLVED'),
      'rejected'     => (Color(0xFFFEE2E2), Color(0xFFB91C1C), 'REJECTED'),
      _              => (ErpColors.bgMuted, ErpColors.textMuted, status.toUpperCase()),
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

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, cta;
  final VoidCallback onTap;
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: ErpColors.textMuted),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ErpColors.accentBlue),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(cta,
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
