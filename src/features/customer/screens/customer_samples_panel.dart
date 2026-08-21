import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../samples/controllers/sample_api.dart';
import '../../samples/models/sample.dart';
import '../../samples/controllers/sample_controllers.dart' show apiMessage;
import '../../samples/screens/sample_detail_page.dart';

// ══════════════════════════════════════════════════════════════
//  WHAT THIS CUSTOMER HAS ASKED FOR
//
//  A brief, not the samples screen in miniature: how many are live,
//  and the few most recent, each openable. Somebody on this page is
//  usually about to talk to the customer, and "you asked us for a
//  navy 25mm three weeks ago, it is on the loom" is the thing worth
//  having in front of them.
//
//  ── Linked, not named ──────────────────────────────────────────
//  Only samples LINKED to this customer appear. A sample typed for a
//  prospect — before they existed in the master — keeps the name it
//  was typed with and carries no link, so it will not show here even
//  if the spelling matches exactly. That is deliberate: matching on
//  the name would also claim every company with a similar one. The
//  raise-sample form now says so at the point the choice is made.
//
//  ── Silence is not the same as zero ────────────────────────────
//  A failed request must not render as "no samples" — on this page
//  that reads as "this customer has never asked for anything", which
//  is a claim about the customer rather than about the network. The
//  three states are kept apart.
// ══════════════════════════════════════════════════════════════

class CustomerSamplesPanel extends StatefulWidget {
  final String customerId;
  const CustomerSamplesPanel({super.key, required this.customerId});

  @override
  State<CustomerSamplesPanel> createState() => _CustomerSamplesPanelState();
}

class _CustomerSamplesPanelState extends State<CustomerSamplesPanel> {
  /// How many rows the brief shows. Enough to recognise the recent
  /// conversation, few enough that it stays a brief — the full list
  /// is one tap away.
  static const _briefRows = 4;

  bool _loading = true;
  String? _error;
  SampleListPage? _page;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // status: 'all' — the brief counts every sample ever raised for
      // them, not just the live ones. A customer with three completed
      // samples and none open has a history worth seeing; filtering to
      // active would show an empty panel and imply there was none.
      final res = await SampleApi.list(
        status: 'all',
        customerId: widget.customerId,
        limit: _briefRows,
      );
      if (!mounted) return;
      setState(() {
        _page = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiMessage(e, 'Could not load samples');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'SAMPLES',
      icon: Icons.science_outlined,
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: ErpColors.accentBlue),
          ),
        ),
      );
    }

    if (_error != null) {
      // Says it could not load, and offers the retry. NOT "no samples".
      return Row(children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: ErpColors.errorRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: TextStyle(fontSize: 12, color: ErpColors.errorRed),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]);
    }

    final page = _page!;
    if (page.total == 0) {
      return Text(
        'No samples raised for this customer.',
        style: TextStyle(fontSize: 12, color: ErpColors.textSecondary),
      );
    }

    final c = page.counts;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── The shape of the history, in one line ──────────────
      Wrap(spacing: 6, runSpacing: 6, children: [
        _Pill(label: '${page.total} total', colour: ErpColors.accentBlue),
        if (c.open > 0) _Pill(label: '${c.open} open', colour: ErpColors.warningAmber),
        if (c.inProgress > 0)
          _Pill(label: '${c.inProgress} in progress', colour: ErpColors.accentBlue),
        if (c.completed > 0)
          _Pill(label: '${c.completed} completed', colour: ErpColors.successGreen),
        if (c.closed > 0)
          _Pill(label: '${c.closed} closed', colour: ErpColors.textMuted),
      ]),
      const SizedBox(height: 10),
      for (final s in page.samples) _SampleLine(row: s),
      if (page.total > page.samples.length) ...[
        const SizedBox(height: 4),
        Text(
          'Showing the ${page.samples.length} most recent of ${page.total}.',
          style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
        ),
      ],
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color colour;
  const _Pill({required this.label, required this.colour});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: colour)),
      );
}

class _SampleLine extends StatelessWidget {
  final SampleRow row;
  const _SampleLine({required this.row});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.to(() => SampleDetailPage(sampleId: row.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
            width: 38,
            child: Text('#${row.sampleNo}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textMuted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary)),
                if (row.quantity > 0)
                  Text('${row.quantity.toStringAsFixed(0)} m',
                      style: TextStyle(
                          fontSize: 11, color: ErpColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(
              label: _statusLabel(row.status),
              colour: _statusColour(row.status)),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: ErpColors.textMuted),
        ]),
      ),
    );
  }
}

String _statusLabel(String s) => switch (s) {
      'in_progress' => 'In progress',
      'open' => 'Open',
      'completed' => 'Completed',
      'closed' => 'Closed',
      _ => s,
    };

Color _statusColour(String s) => switch (s) {
      'open' => ErpColors.warningAmber,
      'in_progress' => ErpColors.accentBlue,
      'completed' => ErpColors.successGreen,
      _ => ErpColors.textMuted,
    };
