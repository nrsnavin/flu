import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/Orders/controllers/order_list_controller.dart';
import 'package:production/src/features/Orders/models/order_list_item.dart';
import 'package:production/src/features/Orders/screens/add_order_page.dart';
import 'package:production/src/features/Orders/screens/order_detail_page.dart';


import '../../PurchaseOrder/services/theme.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  late final OrderListController _c;

  @override
  void initState() {
    super.initState();
    Get.delete<OrderListController>(force: true);
    _c = Get.put(OrderListController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Order",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () async {
          final res = await Get.to(() => AddOrderPage());
          if (res == true) _c.fetchOrders();
        },
      ),
      body: Column(
        children: [
          _StatusTabs(c: _c),
          Expanded(child: _OrderList(c: _c)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Text("Orders", style: ErpTextStyles.pageTitle),
      actions: [
        Obx(() => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              "${_c.orders.length} orders",
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 12),
            ),
          ),
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Status tabs ─────────────────────────────────────────────────────
class _StatusTabs extends StatelessWidget {
  final OrderListController c;
  const _StatusTabs({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border(
              bottom: BorderSide(color: ErpColors.borderLight))),
      child: Obx(() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: c.statuses.map((s) {
            final selected = c.selectedStatus.value == s;
            Color chipText, chipBg;
            switch (s) {
              case "Approved":
                chipText = ErpColors.statusApprovedText;
                chipBg = ErpColors.statusApprovedBg;
                break;
              case "InProgress":
                chipText = ErpColors.statusInProgressText;
                chipBg = ErpColors.statusInProgressBg;
                break;
              case "Completed":
                chipText = ErpColors.statusCompletedText;
                chipBg = ErpColors.statusCompletedBg;
                break;
              case "Cancelled":
                chipText = ErpColors.statusCancelledText;
                chipBg = ErpColors.statusCancelledBg;
                break;
              default:
                chipText = ErpColors.statusOpenText;
                chipBg = ErpColors.statusOpenBg;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => c.changeStatus(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? ErpColors.accentBlue
                        : chipBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? ErpColors.accentBlue
                          : ErpColors.borderLight,
                    ),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: selected ? Colors.white : chipText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      )),
    );
  }
}

// ── List body ────────────────────────────────────────────────────────
class _OrderList extends StatelessWidget {
  final OrderListController c;
  const _OrderList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
                color: ErpColors.accentBlue));
      }
      if (c.orders.isEmpty) {
        return _EmptyState(
          status: c.selectedStatus.value,
          onRefresh: c.fetchOrders,
        );
      }
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.fetchOrders,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: c.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) =>
              _OrderCard(order: c.orders[i], c: c),
        ),
      );
    });
  }
}

// ── Order card ──────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderListItem order;
  final OrderListController c;
  const _OrderCard({required this.order, required this.c});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final isOpen = order.status == "Open";
    final isOverdue =
        order.supplyDate.isBefore(DateTime.now()) &&
            order.status != "Completed" &&
            order.status != "Cancelled";

    final hasFingerprint = order.createdByName != null;
    final wasEdited = order.updatedByName != null &&
        order.updatedByName != order.createdByName;

    return GestureDetector(
      onTap: () => Get.to(
            () => OrderDetailPage(),
        arguments: {"orderId": order.id},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOverdue
                ? ErpColors.errorRed.withOpacity(0.4)
                : ErpColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 20, color: ErpColors.accentBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Order #${order.orderNo}",
                              style: ErpTextStyles.cardTitle,
                            ),
                            const Spacer(),
                            OrderStatusBadge(order.status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(order.customerName,
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: ErpColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            "Order: ${fmt.format(order.date)}",
                            style: const TextStyle(
                                color: ErpColors.textMuted,
                                fontSize: 11),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 11,
                            color: isOverdue
                                ? ErpColors.errorRed
                                : ErpColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Supply: ${fmt.format(order.supplyDate)}",
                            style: TextStyle(
                                color: isOverdue
                                    ? ErpColors.errorRed
                                    : ErpColors.textMuted,
                                fontSize: 11,
                                fontWeight: isOverdue
                                    ? FontWeight.w700
                                    : FontWeight.w400),
                          ),
                        ]),
                        // User fingerprint row
                        if (hasFingerprint) ...[
                          const SizedBox(height: 5),
                          Row(children: [
                            const Icon(Icons.person_outline,
                                size: 11, color: ErpColors.textMuted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                "By ${order.createdByName}",
                                style: const TextStyle(
                                    color: ErpColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (wasEdited) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.edit_outlined,
                                  size: 11, color: ErpColors.textMuted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  order.updatedByName!,
                                  style: const TextStyle(
                                      color: ErpColors.textMuted,
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Action footer (only for Open orders)
            if (isOpen)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                decoration: const BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(8)),
                  border: Border(
                      top: BorderSide(color: ErpColors.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () =>
                              _confirmCancel(context, order.id),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: ErpColors.errorRed),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(4)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text("Cancel",
                              style: TextStyle(
                                  color: ErpColors.errorRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () =>
                              _confirmApprove(context, order.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ErpColors.accentBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(4)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text("Approve",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
                decoration: const BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(8)),
                  border: Border(
                      top: BorderSide(color: ErpColors.borderLight)),
                ),
                child: Row(children: [
                  if (isOverdue)
                    const Row(children: [
                      Icon(Icons.warning_outlined,
                          size: 12, color: ErpColors.errorRed),
                      SizedBox(width: 4),
                      Text("Overdue",
                          style: TextStyle(
                              color: ErpColors.errorRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ])
                  else
                    const SizedBox(),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 16, color: ErpColors.textMuted),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmApprove(BuildContext ctx, String orderId) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: ErpColors.accentBlue, size: 18),
                ),
                const SizedBox(width: 12),
                const Text("Approve Order",
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 12),
              const Text(
                  "This will deduct raw materials from stock. This action cannot be undone.",
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Get.back,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: ErpColors.borderMid)),
                    child: const Text("Cancel",
                        style: TextStyle(
                            color: ErpColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ErpColors.accentBlue,
                        elevation: 0),
                    onPressed: () {
                      Get.back();
                      c.approveOrder(orderId);
                    },
                    child: const Text("Approve",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext ctx, String orderId) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ErpColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: ErpColors.errorRed, size: 18),
                ),
                const SizedBox(width: 12),
                const Text("Cancel Order",
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 12),
              const Text("Are you sure you want to cancel this order?",
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Get.back,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: ErpColors.borderMid)),
                    child: const Text("No",
                        style: TextStyle(
                            color: ErpColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ErpColors.errorRed,
                        elevation: 0),
                    onPressed: () {
                      Get.back();
                      c.cancelOrder(orderId);
                    },
                    child: const Text("Yes, Cancel",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String status;
  final VoidCallback onRefresh;
  const _EmptyState({required this.status, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 32, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text("No $status Orders",
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Text("Tap + to create a new order",
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid)),
            icon: const Icon(Icons.refresh,
                size: 16, color: ErpColors.textSecondary),
            label: const Text("Refresh",
                style: TextStyle(color: ErpColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
