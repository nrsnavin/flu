import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/Orders/controllers/order_detail_controller.dart';

import '../../Job/models/order_model.dart';
import '../../Job/screens/add_job_page.dart';
import '../../Job/screens/job_detail.dart';
import '../../PurchaseOrder/services/theme.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;

    Get.delete<OrderDetailController>(force: true);
    final c = Get.put(OrderDetailController(args["orderId"] as String));

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        titleSpacing: 4,
        title: Obx(() {
          final order = c.order.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order != null
                    ? "Order #${order["orderNo"]}"
                    : "Order Detail",
                style: ErpTextStyles.pageTitle,
              ),
              const Text("Orders  ›  Detail",
                  style: TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10)),
            ],
          );
        }),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(
                  color: ErpColors.accentBlue));
        }

        final order = c.order.value;
        if (order == null) {
          return const Center(
            child: Text("Order not found",
                style: TextStyle(color: ErpColors.textSecondary)),
          );
        }

        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchOrderDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              children: [
                _HeroCard(order: order),
                const SizedBox(height: 10),
                _ActivityTrail(order: order),
                const SizedBox(height: 10),
                _ActionBar(order: order, c: c),
                const SizedBox(height: 12),
                _ElasticTable(order: order),
                const SizedBox(height: 10),
                _RawMaterialSection(order: order),
                const SizedBox(height: 10),
                _JobOrdersSection(order: order),
              ],
            ),
          ),
        );
      }),
    );
  }
}


// ── Hero card ──────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _HeroCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt        = DateFormat('dd MMM yyyy');
    final supplyDate = order["supplyDate"] != null
        ? fmt.format(DateTime.parse(order["supplyDate"].toString()))
        : "—";
    final orderDate  = order["date"] != null
        ? fmt.format(DateTime.parse(order["date"].toString()))
        : "—";

    return Container(
      decoration: BoxDecoration(
        color:        ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: const BoxDecoration(
              color: ErpColors.navyDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: ErpColors.accentBlue.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      size: 24, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Order #${order["orderNo"] ?? "—"}",
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        order["customer"]?["name"] ?? "—",
                        style: const TextStyle(
                            color:    ErpColors.textOnDarkSub,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text("PO: ${order["po"] ?? "—"}",
                          style: const TextStyle(
                              color:    ErpColors.textOnDarkSub,
                              fontSize: 11)),
                    ],
                  ),
                ),
                OrderStatusBadge(order["status"] ?? "Open"),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                    child: _DateStat(label: "ORDER DATE",  value: orderDate)),
                Container(
                    width: 1, height: 32,
                    color: ErpColors.borderLight),
                Expanded(
                    child: _DateStat(label: "SUPPLY DATE", value: supplyDate)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _DateStat extends StatelessWidget {
  final String label;
  final String value;
  const _DateStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color:         ErpColors.textMuted,
                fontSize:      10,
                fontWeight:    FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color:      ErpColors.textPrimary,
                fontSize:   13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}


// ── Activity Trail ─────────────────────────────────────────
class _ActivityTrail extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ActivityTrail({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    String _actorName(dynamic field) {
      if (field is Map) return field["name"] as String? ?? "—";
      return "—";
    }

    String _fmtDate(dynamic val) {
      if (val == null) return "—";
      try { return fmt.format(DateTime.parse(val.toString()).toLocal()); }
      catch (_) { return "—"; }
    }

    final events = <Map<String, dynamic>>[];

    if (order["createdAt"] != null) {
      events.add({
        "label": "Order Created",
        "actor": _actorName(order["createdBy"]),
        "at":    _fmtDate(order["createdAt"]),
        "icon":  Icons.add_circle_outline,
        "color": ErpColors.accentBlue,
      });
    }
    if (order["approvedAt"] != null) {
      events.add({
        "label": "Approved",
        "actor": _actorName(order["approvedBy"]),
        "at":    _fmtDate(order["approvedAt"]),
        "icon":  Icons.check_circle_outline,
        "color": ErpColors.successGreen,
      });
    }
    if (order["startedAt"] != null) {
      events.add({
        "label": "Production Started",
        "actor": _actorName(order["startedBy"]),
        "at":    _fmtDate(order["startedAt"]),
        "icon":  Icons.play_circle_outline,
        "color": ErpColors.warningAmber,
      });
    }
    if (order["completedAt"] != null) {
      events.add({
        "label": "Completed",
        "actor": _actorName(order["completedBy"]),
        "at":    _fmtDate(order["completedAt"]),
        "icon":  Icons.task_alt,
        "color": ErpColors.successGreen,
      });
    }
    if (order["cancelledAt"] != null) {
      events.add({
        "label": "Cancelled",
        "actor": _actorName(order["cancelledBy"]),
        "at":    _fmtDate(order["cancelledAt"]),
        "icon":  Icons.cancel_outlined,
        "color": ErpColors.errorRed,
      });
    }

    if (events.isEmpty) return const SizedBox();

    return ErpSectionCard(
      title: "ACTIVITY TRAIL",
      icon:  Icons.history,
      child: Column(
        children: events.asMap().entries.map((entry) {
          final i      = entry.key;
          final e      = entry.value;
          final isLast = i == events.length - 1;
          final color  = e["color"] as Color;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline spine
              Column(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color:  color.withOpacity(0.12),
                      shape:  BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.45)),
                    ),
                    child: Icon(e["icon"] as IconData,
                        size: 15, color: color),
                  ),
                  if (!isLast)
                    Container(
                      width: 2, height: 32,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin:  Alignment.topCenter,
                          end:    Alignment.bottomCenter,
                          colors: [
                            color.withOpacity(0.3),
                            ErpColors.borderLight,
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(e["label"] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize:   13,
                              color:      ErpColors.textPrimary)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.person_outline,
                            size: 11, color: ErpColors.textMuted),
                        const SizedBox(width: 4),
                        Text(e["actor"] as String,
                            style: const TextStyle(
                                color:    ErpColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 11, color: ErpColors.textMuted),
                        const SizedBox(width: 4),
                        Text(e["at"] as String,
                            style: const TextStyle(
                                color:    ErpColors.textMuted,
                                fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}


// ── Action bar ─────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final Map<String, dynamic> order;
  final OrderDetailController c;
  const _ActionBar({required this.order, required this.c});

  @override
  Widget build(BuildContext context) {
    final status     = order["status"] as String? ?? "";
    final canApprove = order["canApprove"] as bool? ?? true;

    if (status == "Open") {
      return Obx(() => Column(
        children: [
          if (!canApprove)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ErpColors.errorRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ErpColors.errorRed.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: ErpColors.errorRed),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Insufficient stock — receive pending materials before approving.",
                    style: TextStyle(
                        fontSize:   12,
                        color:      ErpColors.errorRed,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          _ActionButton(
            label:   "Approve Order",
            icon:    Icons.check_circle_outline,
            color:   canApprove
                ? ErpColors.accentBlue
                : ErpColors.textSecondary,
            loading: c.isActioning.value,
            onTap:   canApprove ? () => _confirmApprove(context, c) : null,
          ),
        ],
      ));
    }

    if (status == "Approved") {
      return Obx(() => _ActionButton(
        label:   "Start Production",
        icon:    Icons.play_circle_outline,
        color:   ErpColors.warningAmber,
        loading: c.isActioning.value,
        onTap:   () => _confirmStart(context, c),
      ));
    }

    return const SizedBox();
  }

  void _confirmApprove(BuildContext ctx, OrderDetailController c) {
    Get.dialog(Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_circle_outline,
                    color: ErpColors.accentBlue, size: 18),
              ),
              const SizedBox(width: 12),
              const Text("Approve Order",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            const Text(
              "This will deduct raw materials from stock. Cannot be undone.",
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: Get.back,
                      child: const Text("Cancel"))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: ErpColors.accentBlue, elevation: 0),
                  onPressed: () {
                    Get.back();
                    c.approveOrder();
                  },
                  child: const Text("Approve",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    ));
  }

  void _confirmStart(BuildContext ctx, OrderDetailController c) {
    Get.dialog(Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: ErpColors.warningAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.play_circle_outline,
                    color: ErpColors.warningAmber, size: 18),
              ),
              const SizedBox(width: 12),
              const Text("Start Production",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            const Text(
              "Move this order to In Progress and begin production?",
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: Get.back,
                      child: const Text("Cancel"))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: ErpColors.warningAmber, elevation: 0),
                  onPressed: () {
                    Get.back();
                    c.startProduction();
                  },
                  child: const Text("Start",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    ));
  }
}


class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        icon: loading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18, color: Colors.white),
        label: Text(label,
            style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
                fontSize:   14)),
      ),
    );
  }
}


// ── Elastic table ───────────────────────────────────────────
class _ElasticTable extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ElasticTable({required this.order});

  @override
  Widget build(BuildContext context) {
    final elastics = (order["elastics"] as List<dynamic>?) ?? [];
    if (elastics.isEmpty) return const SizedBox();

    return ErpSectionCard(
      title: "ELASTIC TRACKING",
      icon:  Icons.layers_outlined,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              color: ErpColors.navyDark.withOpacity(0.04),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text("ELASTIC",
                        style: ErpTextStyles.fieldLabel)),
                _ColHeader("ORDERED"),
                _ColHeader("PRODUCED"),
                _ColHeader("PACKED"),
                _ColHeader("PENDING"),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...elastics.map((e) {
            final pending = (e["pending"] ?? 0) as int;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: pending > 0
                    ? ErpColors.bgSurface
                    : ErpColors.statusCompletedBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: pending > 0
                      ? ErpColors.borderLight
                      : ErpColors.statusCompletedBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(e["name"] ?? "—",
                        style: const TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            color:      ErpColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  _ColValue("${e["ordered"]  ?? 0}",
                      color: ErpColors.textPrimary),
                  _ColValue("${e["produced"] ?? 0}",
                      color: ErpColors.accentBlue),
                  _ColValue("${e["packed"]   ?? 0}",
                      color: ErpColors.warningAmber),
                  _ColValue("${e["pending"]  ?? 0}",
                      color: pending > 0
                          ? ErpColors.errorRed
                          : ErpColors.successGreen),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}


class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Text(text,
        style: ErpTextStyles.fieldLabel,
        textAlign: TextAlign.center),
  );
}


class _ColValue extends StatelessWidget {
  final String value;
  final Color color;
  const _ColValue(this.value, {required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Text(value,
        style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w800),
        textAlign: TextAlign.center),
  );
}


// ── Raw material section ──────────────────────────────────
class _RawMaterialSection extends StatelessWidget {
  final Map<String, dynamic> order;
  const _RawMaterialSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final materials =
        (order["rawMaterialRequired"] as List<dynamic>?) ?? [];
    if (materials.isEmpty) return const SizedBox();

    final insufficientCount = materials
        .where((m) => !(m["stockSufficient"] as bool? ?? true))
        .length;
    final allSufficient = insufficientCount == 0;

    return ErpSectionCard(
      title: "RAW MATERIAL REQUIREMENT",
      icon:  Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: allSufficient
                  ? ErpColors.successGreen.withOpacity(0.07)
                  : ErpColors.errorRed.withOpacity(0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: allSufficient
                    ? ErpColors.successGreen.withOpacity(0.3)
                    : ErpColors.errorRed.withOpacity(0.3),
              ),
            ),
            child: Row(children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: ErpColors.successGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:        ErpColors.successGreen.withOpacity(0.5),
                      blurRadius:   4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text("LIVE STOCK",
                  style: TextStyle(
                      fontSize:      10,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 0.8,
                      color:         ErpColors.successGreen)),
              const SizedBox(width: 10),
              Container(width: 1, height: 12, color: ErpColors.borderMid),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allSufficient
                      ? "All materials have sufficient stock"
                      : "$insufficientCount material${insufficientCount == 1 ? '' : 's'} below required level",
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color: allSufficient
                          ? ErpColors.successGreen
                          : ErpColors.errorRed),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        allSufficient ? ErpColors.successGreen : ErpColors.errorRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  allSufficient ? "READY" : "NOT READY",
                  style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      9,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
            ]),
          ),
          ...materials.map((m) {
            final required        = (m["requiredWeight"] ?? 0).toDouble();
            final inStock         = (m["inStock"]        ?? 0).toDouble();
            final stockSufficient = m["stockSufficient"] as bool? ??
                inStock >= required;
            final pct = required > 0
                ? (inStock / required).clamp(0.0, 1.0)
                : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stockSufficient
                    ? ErpColors.statusCompletedBg
                    : ErpColors.statusCancelledBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: stockSufficient
                      ? ErpColors.statusCompletedBorder
                      : ErpColors.statusCancelledBorder,
                  width: stockSufficient ? 1 : 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(m["name"] ?? "—",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize:   13,
                              color:      ErpColors.textPrimary)),
                    ),
                    if (!stockSufficient)
                      _StockBadge(label: "INSUFFICIENT", color: ErpColors.errorRed)
                    else
                      _StockBadge(label: "SUFFICIENT",   color: ErpColors.successGreen),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value:           pct.toDouble(),
                      minHeight:       5,
                      backgroundColor: ErpColors.borderLight,
                      color: stockSufficient
                          ? ErpColors.successGreen
                          : ErpColors.errorRed,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(
                      "Required: ${required.toStringAsFixed(2)} kg",
                      style: const TextStyle(
                          color: ErpColors.textSecondary, fontSize: 11),
                    ),
                    const Spacer(),
                    Container(
                      width: 5, height: 5,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(
                        color: ErpColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      "In Stock: ${inStock.toStringAsFixed(2)} kg",
                      style: TextStyle(
                          color: stockSufficient
                              ? ErpColors.successGreen
                              : ErpColors.errorRed,
                          fontSize:   11,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                  if (!stockSufficient) ...[  
                    const SizedBox(height: 4),
                    Text(
                      "Short by ${(required - inStock).toStringAsFixed(2)} kg — receive more stock to approve",
                      style: const TextStyle(
                          color:     ErpColors.errorRed,
                          fontSize:  11,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}


class _StockBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StockBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border:       Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(
          color:         color,
          fontSize:      9,
          fontWeight:    FontWeight.w800,
          letterSpacing: 0.4),
    ),
  );
}


// ── Job orders section ────────────────────────────────────
class _JobOrdersSection extends StatelessWidget {
  final Map<String, dynamic> order;
  const _JobOrdersSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final jobs   = (order["jobs"] as List<dynamic>?) ?? [];
    final status = order["status"] as String? ?? "";

    return ErpSectionCard(
      title: "JOB ORDERS",
      icon:  Icons.work_outline,
      child: Column(
        children: [
          if (status == "InProgress")
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Get.to(() =>
                      AddJobOrderPage(order: OrderModel.fromJson(order)));
                },
                style: OutlinedButton.styleFrom(
                  side:  const BorderSide(color: ErpColors.accentBlue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon:  const Icon(Icons.add, size: 16, color: ErpColors.accentBlue),
                label: const Text("Add Job Order",
                    style: TextStyle(
                        color:      ErpColors.accentBlue,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          if (status == "InProgress") const SizedBox(height: 10),
          if (jobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text("No job orders yet",
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 13)),
            )
          else
            ...jobs.asMap().entries.map((entry) {
              final i     = entry.key;
              final j     = entry.value as Map;
              final jobId = j["job"] is Map
                  ? j["job"]["_id"]?.toString()
                  : j["job"]?.toString();

              return GestureDetector(
                onTap: () {
                  if (jobId != null) {
                    Get.to(() => JobDetailPage(), arguments: jobId);
                  }
                },
                child: Container(
                  margin:  const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color:        ErpColors.bgMuted,
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(color: ErpColors.borderLight),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text("${i + 1}",
                          style: const TextStyle(
                              color:      ErpColors.accentBlue,
                              fontSize:   12,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Job #${j["no"] ?? i + 1}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize:   13,
                                  color:      ErpColors.textPrimary)),
                          if (jobId != null)
                            Text(jobId,
                                style: const TextStyle(
                                    color:    ErpColors.textMuted,
                                    fontSize: 10),
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 16, color: ErpColors.textMuted),
                  ]),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
