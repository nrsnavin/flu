import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/complaint_controller.dart';
import '../models/complaint.dart';

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
//  "No other job carries these lots" is a real and reassuring answer,
//  and a blank panel is indistinguishable from one that failed. But it
//  is said ONLY when lots were traced and nobody else carries them.
//  When no lot is recorded against the job there was nothing to trace,
//  and the server's own words for that are shown instead: it "is not
//  evidence that no other order is affected".
//
//  ── Still here comes first ─────────────────────────────────────
//  As on the web: the jobs that have not left are the only ones that
//  can still be stopped, so they are listed above the customers who
//  already have the goods.
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
                      style: TextStyle(color: ErpColors.textSecondary)),
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
                // The moment it was filed, on this phone's clock: read as
                // it came (UTC), one filed before 05:30 showed the day before.
                _row('Raised', DateFormat('dd MMM yyyy').format(x.date!.toLocal())),
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
                  Text(
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
                style: TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
          if (t != null && !t.ok)
            Text(
              t.message ?? 'There is no trail to follow for this complaint.',
              style: TextStyle(fontSize: 13, color: ErpColors.textSecondary),
            ),
          if (t != null && t.ok) ...[
            if (t.lots.isNotEmpty) ...[
              _traceHeading('Lots involved (${t.lots.length})'),
              for (final l in t.lots)
                _traceRow(
                  (l['lotNo'] ?? '').toString().isEmpty
                      ? 'Unnumbered lot'
                      : l['lotNo'].toString(),
                  ComplaintTrace.lotLine(l),
                ),
              const SizedBox(height: 10),
            ],
            if (t.nobodyElse)
              // A real, reassuring answer — said only when lots were
              // traced and nobody else carries them.
              Text(
                'No other job carries ${t.lots.length == 1 ? 'this lot' : 'these lots'}.',
                style: TextStyle(fontSize: 13, color: ErpColors.textSecondary),
              ),
            if (t.otherJobs > 0) ...[
              // Containable first: these are the ones that can be stopped.
              _exposure('Still here — stop these', t.inHouse,
                  'Nothing has gone out.', ErpColors.statusPartialText),
              _exposure('In transit', t.inTransit,
                  'Dispatched, not yet marked delivered.', ErpColors.statusPartialText),
              _exposure('Already delivered — call these customers', t.delivered,
                  'The goods are with them.', ErpColors.errorRed),
            ],
            for (final caveat in t.caveats) ...[
              const SizedBox(height: 8),
              Text(caveat,
                  style: TextStyle(
                      fontSize: t.nothingToTrace ? 13 : 11,
                      height: 1.35,
                      color: t.nothingToTrace
                          ? ErpColors.textPrimary
                          : ErpColors.textMuted)),
            ],
            if (t.nothingToTrace && t.caveats.isEmpty)
              Text(
                'No yarn lot is recorded against this job, so there is nothing '
                'to trace. That is not evidence that no other order is affected.',
                style: TextStyle(fontSize: 13, color: ErpColors.textPrimary),
              ),
          ],
        ]);
      });

  Widget _traceHeading(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color ?? ErpColors.textSecondary)),
      );

  /// One group of the other jobs carrying the lot, by where the goods are.
  Widget _exposure(String title, List<Map<String, dynamic>> rows, String sub, Color tone) =>
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _traceHeading('$title (${rows.length})', color: tone),
            Text(sub, style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('None.',
                    style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
              ),
            for (final r in rows)
              _traceRow(
                (r['customerName'] ?? '').toString().isEmpty
                    ? 'Unnamed customer'
                    : r['customerName'].toString(),
                [
                  ComplaintTrace.jobLine(r),
                  // A challan names an order and a product, not a job:
                  // where an order has two jobs for the product, say so.
                  if (r['certain'] == false) 'may not be this job',
                  if (r['finishedNotShipped'] == true) 'finished, still here',
                ].join(' · '),
              ),
          ],
        ),
      );

  /// A name, and what is known about it beneath.
  Widget _traceRow(String title, String detail) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ErpColors.textPrimary)),
            if (detail.isNotEmpty)
              Text(detail,
                  style: TextStyle(
                      fontSize: 12, color: ErpColors.textSecondary)),
          ],
        ),
      );

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
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _prose(String title, String body) => _card(title, [
        Text(body,
            style: TextStyle(
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
                  style: TextStyle(
                      fontSize: 12, color: ErpColors.textMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13, color: ErpColors.textPrimary)),
            ),
          ],
        ),
      );
}
