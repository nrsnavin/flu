import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/complaint_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ONE COMPLAINT, AND WHO ELSE GOT THE SAME CLOTH
//
//  The trace is the reason this is worth opening on a phone. A shade
//  complaint about one delivery is a customer-service problem; the
//  same complaint traced back to a yarn lot and forward to every other
//  job that used it is a recall, and the difference is one tap.
//
//  ── It is loaded on demand ─────────────────────────────────────
//  The walk goes lot → batch → job and is the expensive part of this
//  module. Most people open a complaint to read it; only some go
//  looking for who else is affected. Loading it eagerly would make
//  every open slow to serve the minority.
//
//  ── An empty trace is stated, not left blank ───────────────────
//  "No other jobs share a lot with this one" is a real and reassuring
//  answer. A blank panel is indistinguishable from one that failed.
// ══════════════════════════════════════════════════════════════

class ComplaintDetailPage extends StatefulWidget {
  const ComplaintDetailPage({super.key, required this.complaintId});

  final String complaintId;

  @override
  State<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends State<ComplaintDetailPage> {
  late final ComplaintDetailController c;
  final _tag = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    c = Get.put(ComplaintDetailController(widget.complaintId), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<ComplaintDetailController>(tag: _tag, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Complaint'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.complaint.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ErpColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: c.fetch, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        final x = c.complaint.value;
        if (x == null) return const SizedBox.shrink();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _card('The complaint', [
              _row('Customer', x.customerName),
              _row('Status', x.status),
              _row('Category', x.category),
              if (x.elasticName != '—') _row('Product', x.elasticName),
              if (x.jobOrderNo != null) _row('Job', x.jobOrderNo!),
              if (x.orderNo != null) _row('Order', x.orderNo!),
              if (x.quantity > 0) _row('Quantity', x.quantity.toStringAsFixed(0)),
              if (x.date != null)
                _row('Raised', DateFormat('dd MMM yyyy').format(x.date!)),
            ]),
            if (x.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              _prose('What they said', x.reason),
            ],
            if (x.feedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              _prose('Feedback', x.feedback),
            ],
            if (x.resolution.isNotEmpty) ...[
              const SizedBox(height: 10),
              _prose('Resolution', x.resolution),
            ],
            const SizedBox(height: 10),
            _traceCard(),
          ],
        );
      }),
    );
  }

  Widget _traceCard() => Obx(() {
        final t = c.trace.value;
        return _card('Who else got the same cloth', [
          if (t == null && !c.isTracing.value && c.traceError.value == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trace this back to its yarn lots and forward to every '
                    'other job that used them.',
                    style: TextStyle(
                        fontSize: 12, color: ErpColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: c.loadTrace,
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('Trace the lot'),
                  ),
                ],
              ),
            ),
          if (c.isTracing.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (c.traceError.value != null)
            Text(c.traceError.value!,
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
          if (t != null && t.isEmpty)
            // A real, reassuring answer — not a blank panel that could
            // equally mean the trace failed.
            const Text(
              'No other jobs share a yarn lot with this one.',
              style: TextStyle(fontSize: 13, color: ErpColors.textSecondary),
            ),
          if (t != null && !t.isEmpty) ...[
            if (t.lots.isNotEmpty) ...[
              const Text('Lots involved',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textSecondary)),
              const SizedBox(height: 4),
              for (final l in t.lots) _traceRow(l, 'lotNo', 'material'),
              const SizedBox(height: 10),
            ],
            if (t.exposedJobs.isNotEmpty) ...[
              Text('${t.exposedJobs.length} other job(s) exposed',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textSecondary)),
              const SizedBox(height: 4),
              for (final j in t.exposedJobs) _traceRow(j, 'jobOrderNo', 'customerName'),
            ],
            if (t.note != null) ...[
              const SizedBox(height: 8),
              Text(t.note!,
                  style: const TextStyle(
                      fontSize: 11, color: ErpColors.textMuted)),
            ],
          ],
        ]);
      });

  /// The trace rows are the server's shape to change, so this reads
  /// them defensively rather than binding to a model that would break
  /// the screen the next time a field is added.
  Widget _traceRow(Map<String, dynamic> row, String primary, String secondary) {
    final a = row[primary]?.toString();
    final b = row[secondary]?.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a == null || a.isEmpty ? '—' : a,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ErpColors.textPrimary),
            ),
          ),
          if (b != null && b.isNotEmpty)
            Text(b,
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _prose(String title, String body) => _card(title, [
        Text(body,
            style: const TextStyle(
                fontSize: 13, color: ErpColors.textPrimary, height: 1.4)),
      ]);

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: ErpColors.textMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: ErpColors.textPrimary)),
            ),
          ],
        ),
      );
}
