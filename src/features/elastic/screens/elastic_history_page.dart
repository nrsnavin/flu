import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_history_controller.dart';
import '../models/elastic_history.dart';

// ══════════════════════════════════════════════════════════════
//  WHERE THIS ELASTIC HAS BEEN
//
//  Every order it was on and every job that ran it. The quantities are
//  this elastic's own line, pulled out server-side — an order carrying
//  four products would otherwise report the other three as this one's.
//
//  Both lists page. The running totals at the top are explicitly
//  totals over what is LOADED, not over everything: a figure that
//  quietly meant "the first twenty" would be worse than no figure.
// ══════════════════════════════════════════════════════════════

final _qtyFmt = NumberFormat('#,##0.##', 'en_IN');
String _qty(double v) => _qtyFmt.format(v);

const _purple = Color(0xFF7C3AED);

/// A colour per order/job status, using the same vocabulary the rest of
/// the app already speaks.
Color _statusColor(String s) {
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

class ElasticHistoryPageView extends StatefulWidget {
  final String elasticId;
  final String elasticName;
  const ElasticHistoryPageView({
    super.key,
    required this.elasticId,
    required this.elasticName,
  });

  @override
  State<ElasticHistoryPageView> createState() => _ElasticHistoryPageViewState();
}

class _ElasticHistoryPageViewState extends State<ElasticHistoryPageView>
    with SingleTickerProviderStateMixin {
  late final ElasticHistoryController c;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Get.delete<ElasticHistoryController>(force: true);
    c = Get.put(ElasticHistoryController(
      elasticId: widget.elasticId,
      elasticName: widget.elasticName,
    ));
  }

  @override
  void dispose() {
    _tabs.dispose();
    Get.delete<ElasticHistoryController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: AppBar(
          backgroundColor: ErpColors.navyDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Product History', style: ErpTextStyles.pageTitle),
              Text(widget.elasticName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10)),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Obx(() => TabBar(
                  controller: _tabs,
                  indicatorColor: ErpColors.accentLight,
                  labelColor: Colors.white,
                  unselectedLabelColor: ErpColors.textOnDarkSub,
                  labelStyle: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800),
                  tabs: [
                    Tab(text: 'ORDERS (${c.ordersTotal.value})'),
                    Tab(text: 'JOBS (${c.jobsTotal.value})'),
                  ],
                )),
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_OrdersTab(c: c), _JobsTab(c: c)],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  ORDERS
// ══════════════════════════════════════════════════════════════
class _OrdersTab extends StatelessWidget {
  final ElasticHistoryController c;
  const _OrdersTab({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
        if (c.ordersLoading.value && c.orders.isEmpty) {
          return Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }

        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchOrders,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
            children: [
              if (c.ordersError.value != null) ...[
                _Note(c.ordersError.value!, ErpColors.errorRed,
                    Icons.error_outline),
                const SizedBox(height: 10),
              ],

              _Totals(
                loaded: c.orders.length,
                total: c.ordersTotal.value,
                complete: c.ordersComplete,
                figures: [
                  _Figure('Ordered', c.orderedLoaded, ErpColors.accentBlue),
                  _Figure('Packed', c.packedLoaded, ErpColors.successGreen),
                ],
              ),
              const SizedBox(height: 10),

              // A deleted order is not history, it is a mistake being
              // undone — hidden by default, askable for.
              _IncludeToggle(
                label: 'Include deleted orders',
                value: c.includeDeleted.value,
                onChanged: (v) => c.includeDeleted.value = v,
              ),
              const SizedBox(height: 12),

              if (c.orders.isEmpty)
                const _Empty(
                  icon: Icons.receipt_long_outlined,
                  title: 'Not on any order yet',
                  body: 'Once this elastic is ordered, every order it '
                      'appears on shows up here.',
                )
              else
                ...c.orders.map((o) => _OrderCard(o: o)),

              if (c.ordersHasMore.value)
                _LoadMore(
                  busy: c.ordersLoadingMore.value,
                  remaining: c.ordersTotal.value - c.orders.length,
                  onTap: c.loadMoreOrders,
                ),
            ],
          ),
        );
      });
}

class _OrderCard extends StatelessWidget {
  final ElasticOrderRow o;
  const _OrderCard({required this.o});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(o.status);
    final f = o.packedFraction;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: ErpColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (o.customerName.isNotEmpty) o.customerName,
                    if (o.po.isNotEmpty) 'PO ${o.po}',
                    if (o.date != null)
                      DateFormat('dd MMM yyyy').format(o.date!),
                  ].join('  ·  '),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: ErpColors.textSecondary),
                ),
              ],
            ),
          ),
          _StatusPill(o.status, color),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Cell('Ordered', o.ordered, ErpColors.textPrimary),
          _Cell('Produced', o.produced, _purple),
          _Cell('Packed', o.packed, ErpColors.successGreen),
        ]),
        if (f != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: f,
              minHeight: 5,
              backgroundColor: ErpColors.bgMuted,
              valueColor: AlwaysStoppedAnimation(ErpColors.successGreen),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(f * 100).toStringAsFixed(0)}% packed',
              style: TextStyle(
                  fontSize: 9.5, color: ErpColors.textMuted)),
        ],
        if (o.supplyDate != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.event_rounded,
                size: 11, color: ErpColors.accentBlue),
            const SizedBox(width: 4),
            Text('Supply by ${DateFormat('dd MMM yyyy').format(o.supplyDate!)}',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ErpColors.accentBlue)),
          ]),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  JOBS
// ══════════════════════════════════════════════════════════════
class _JobsTab extends StatelessWidget {
  final ElasticHistoryController c;
  const _JobsTab({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
        if (c.jobsLoading.value && c.jobs.isEmpty) {
          return Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }

        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchJobs,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
            children: [
              if (c.jobsError.value != null) ...[
                _Note(c.jobsError.value!, ErpColors.errorRed,
                    Icons.error_outline),
                const SizedBox(height: 10),
              ],

              _Totals(
                loaded: c.jobs.length,
                total: c.jobsTotal.value,
                complete: c.jobsComplete,
                figures: [
                  _Figure('Produced', c.producedLoaded, _purple),
                  _Figure('Wastage', c.wastageLoaded, ErpColors.warningAmber),
                ],
              ),
              const SizedBox(height: 10),

              // A cancelled job made nothing, but it is still part of the
              // record of what was attempted — a different thing from a
              // deleted order, and worth being able to see.
              _IncludeToggle(
                label: 'Include cancelled jobs',
                value: c.includeCancelled.value,
                onChanged: (v) => c.includeCancelled.value = v,
              ),
              const SizedBox(height: 12),

              if (c.jobs.isEmpty)
                const _Empty(
                  icon: Icons.precision_manufacturing_outlined,
                  title: 'Never run yet',
                  body: 'Once a job is raised for this elastic, every run '
                      'shows up here with what it made and wasted.',
                )
              else
                ...c.jobs.map((j) => _JobCard(j: j)),

              if (c.jobsHasMore.value)
                _LoadMore(
                  busy: c.jobsLoadingMore.value,
                  remaining: c.jobsTotal.value - c.jobs.length,
                  onTap: c.loadMoreJobs,
                ),
            ],
          ),
        );
      });
}

class _JobCard extends StatelessWidget {
  final ElasticJobRow j;
  const _JobCard({required this.j});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(j.status);
    final w = j.wastagePct;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(j.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: ErpColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (j.orderNo != null) 'Order #${j.orderNo}',
                    if (j.customerName.isNotEmpty) j.customerName,
                    if (j.date != null)
                      DateFormat('dd MMM yyyy').format(j.date!),
                  ].join('  ·  '),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: ErpColors.textSecondary),
                ),
              ],
            ),
          ),
          _StatusPill(j.status, color),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Cell('Planned', j.planned, ErpColors.textPrimary),
          _Cell('Produced', j.produced, _purple),
          _Cell('Packed', j.packed, ErpColors.successGreen),
          _Cell('Wastage', j.wastage, ErpColors.warningAmber),
        ]),
        // Waste is measured against what actually ran, not against the
        // plan: a job that only made half its plan did not waste the
        // half it never wove.
        if (w != null && j.wastage > 0) ...[
          const SizedBox(height: 6),
          Text('${w.toStringAsFixed(1)}% of what it produced',
              style: TextStyle(
                  fontSize: 9.5, color: ErpColors.textMuted)),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHARED PIECES
// ══════════════════════════════════════════════════════════════

class _Figure {
  final String label;
  final double value;
  final Color color;
  const _Figure(this.label, this.value, this.color);
}

class _Totals extends StatelessWidget {
  final int loaded;
  final int total;
  final bool complete;
  final List<_Figure> figures;
  const _Totals({
    required this.loaded,
    required this.total,
    required this.complete,
    required this.figures,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(children: [
          Row(
            children: figures
                .map((f) => Expanded(
                      child: Column(children: [
                        Text(_qty(f.value),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: f.color)),
                        const SizedBox(height: 2),
                        Text(f.label,
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.textMuted)),
                      ]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Said plainly, because it is the difference between a figure
          // you can quote and one you cannot.
          Text(
            complete
                ? 'Across all $total'
                : 'Across the $loaded of $total loaded so far',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: complete ? ErpColors.textMuted : ErpColors.warningAmber,
            ),
          ),
        ]),
      );
}

class _Cell extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Cell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: ErpColors.textMuted)),
          const SizedBox(height: 2),
          Text(_qty(value),
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusPill(this.status, this.color);

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final text = status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _IncludeToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _IncludeToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ErpColors.textSecondary)),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: ErpColors.accentBlue,
        ),
      ]);
}

class _LoadMore extends StatelessWidget {
  final bool busy;
  final int remaining;
  final VoidCallback onTap;
  const _LoadMore({
    required this.busy,
    required this.remaining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: ErpColors.accentBlue),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: busy ? null : onTap,
            icon: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ErpColors.accentBlue))
                : Icon(Icons.expand_more_rounded,
                    size: 16, color: ErpColors.accentBlue),
            label: Text(
              busy
                  ? 'Loading…'
                  : 'Load more${remaining > 0 ? ' ($remaining left)' : ''}',
              style: TextStyle(
                  color: ErpColors.accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Empty({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Icon(icon, size: 30, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          ),
        ]),
      );
}

class _Note extends StatelessWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const _Note(this.msg, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: color, fontSize: 11)),
          ),
        ]),
      );
}
