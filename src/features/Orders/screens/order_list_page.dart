import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/core/api_client.dart';
import 'package:production/src/features/Orders/controllers/order_list_controller.dart';
import 'package:production/src/features/Orders/controllers/order_list_eta_controller.dart';
import 'package:production/src/features/Orders/models/order_list_item.dart';
import 'package:production/src/features/Orders/screens/add_order_page.dart';
import 'package:production/src/features/Orders/screens/order_detail_page.dart';
import 'package:production/src/features/Orders/widgets/order_eta_chip.dart';


import '../../PurchaseOrder/services/theme.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  late final OrderListController _c;
  late final OrderListEtaController _etaC;

  @override
  void initState() {
    super.initState();
    Get.delete<OrderListController>(force: true);
    _c = Get.put(OrderListController());
    Get.delete<OrderListEtaController>(force: true);
    _etaC = Get.put(OrderListEtaController());

    // Refetch ETAs whenever the visible list changes (status tab
    // change, pull-to-refresh, optimistic mutations). Debounced via
    // GetX's ever() — fires once per orders.assignAll().
    ever(_c.orders, (orders) {
      _etaC.fetchForOrders([
        for (final o in orders) (id: o.id, status: o.status),
      ]);
    });
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
              case "Deleted":
                chipText = const Color(0xFF64748B);
                chipBg   = const Color(0xFFF1F5F9);
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
                            // 🪪 Quick edit / delete menu — Open only
                            if (isOpen)
                              _OrderCardMenu(orderId: order.id, c: c),
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
                        // Predicted-completion chip for in-flight orders.
                        // Reads from the singleton OrderListEtaController
                        // so the chip lights up reactively when the bulk
                        // fetch returns. Always shows *something* for
                        // running orders — loading dots, the chip, or
                        // an explicit "ETA unavailable" — so an admin
                        // never has to guess whether the fetch failed.
                        if (order.status == "Approved" ||
                            order.status == "InProgress")
                          Obx(() {
                            final etaC = Get.find<OrderListEtaController>();
                            final summary = etaC.byOrderId[order.id];
                            final loading = etaC.loading.value;
                            final lastError = etaC.lastError.value;
                            // Per-order reason takes precedence over
                            // the global lastError — it tells the
                            // admin *this row* failed even when the
                            // bulk fetch succeeded overall.
                            final perRow = etaC.reasonByOrderId[order.id];
                            if (summary != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: OrderEtaChip(summary: summary),
                              );
                            }
                            // NOTHING_REMAINING = order is functionally
                            // done. No chip needed; the order list
                            // already shows the produced quantity.
                            if (perRow == 'NOTHING_REMAINING') {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: _EtaPendingChip(
                                loading: loading,
                                error: lastError,
                                rowReason: perRow,
                              ),
                            );
                          }),
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
                  child: _ListDialogButton(
                    label:    "Approve",
                    color:    ErpColors.accentBlue,
                    orderId:  orderId,
                    c:        c,
                    action:   () => c.approveOrder(orderId),
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
                  child: _ListDialogButton(
                    label:    "Yes, Cancel",
                    color:    ErpColors.errorRed,
                    orderId:  orderId,
                    c:        c,
                    action:   () => c.cancelOrder(orderId),
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

// Maps a backend ok:false reason into a human-readable chip label
// so admins can self-diagnose instead of seeing "ETA unavailable".
String _humanReason(String reason) {
  switch (reason) {
    case 'NOT_FOUND':         return 'Order not found';
    case 'NOT_RUNNING':       return 'Order not in production';
    case 'NO_ACTIVE_JOBS':    return 'No active jobs yet';
    case 'NOTHING_REMAINING': return 'Already produced';
    case 'NO_RATE':           return 'No production rate data';
    case 'COMPUTE_ERROR':     return 'Backend compute error';
    case 'UNKNOWN':           return 'No estimate available';
  }
  // Surface raw reason for any unmapped backend value so the admin
  // can report it.
  return reason;
}

// ── Inline placeholder when the ETA hasn't loaded for this row yet ──
// Always visible for in-flight orders so the admin can tell the chip
// tried. When the last bulk fetch surfaced an error (HTTP, network)
// OR the backend returned a per-row reason, shows it inline so the
// row points at the actual cause.
class _EtaPendingChip extends StatelessWidget {
  final bool loading;
  final String? error;
  final String? rowReason; // backend ok:false reason for this specific order
  const _EtaPendingChip({required this.loading, this.error, this.rowReason});

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    final hasRowReason = rowReason != null && rowReason!.isNotEmpty;
    final tone = loading
        ? ErpColors.textSecondary
        : (hasError || hasRowReason)
            ? ErpColors.errorRed
            : ErpColors.textMuted;
    String label;
    IconData icon;
    if (loading) {
      label = 'Estimating…';
      icon = Icons.hourglass_top_rounded;
    } else if (hasError) {
      final e = error!;
      final short = e.length > 36 ? '${e.substring(0, 36)}…' : e;
      label = 'ETA: $short';
      icon = Icons.error_outline_rounded;
    } else if (hasRowReason) {
      label = 'ETA: ${_humanReason(rowReason!)}';
      icon = Icons.info_outline_rounded;
    } else {
      label = 'ETA unavailable';
      icon = Icons.help_outline_rounded;
    }

    final highlight = hasError || hasRowReason;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? ErpColors.errorRed.withOpacity(0.06)
            : ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight
              ? ErpColors.errorRed.withOpacity(0.3)
              : ErpColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: tone),
            )
          else
            Icon(icon, size: 10, color: tone),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone, fontSize: 10, fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick edit/delete menu — shown on Open cards ──────────────────
class _OrderCardMenu extends StatelessWidget {
  final String orderId;
  final OrderListController c;
  const _OrderCardMenu({required this.orderId, required this.c});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      icon: const Icon(Icons.more_vert,
          size: 18, color: ErpColors.textSecondary),
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        if (value == 'edit') {
          // Pre-fetch detail so the edit form lands fully hydrated
          // (customer, dates, elastics, quantities). Show a tiny
          // spinner overlay so the tap doesn't feel dead while we
          // wait on the network.
          Get.dialog(
            const Center(
              child: SizedBox(
                width: 32, height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: ErpColors.accentBlue,
                ),
              ),
            ),
            barrierDismissible: false,
          );
          try {
            final dio = ApiClient.instance.dio;
            final res = await dio.get(
              '/order/get-orderDetail',
              queryParameters: {'id': orderId},
            );
            final data = res.data['data'] as Map<String, dynamic>?;
            if (Get.isDialogOpen ?? false) Get.back();
            await Get.to(() => AddOrderPage(
                  editingOrderId: orderId,
                  initialOrder:   data,
                ));
            c.fetchOrders();
          } on DioException catch (e) {
            if (Get.isDialogOpen ?? false) Get.back();
            Get.snackbar(
              'Error',
              e.response?.data?['message'] ?? 'Failed to load order',
              backgroundColor: ErpColors.errorRed,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
          } catch (_) {
            if (Get.isDialogOpen ?? false) Get.back();
          }
        } else if (value == 'delete') {
          await _confirmDelete(context);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16, color: ErpColors.accentBlue),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: ErpColors.errorRed),
            SizedBox(width: 8),
            Text('Delete'),
          ]),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final reasonCtrl = TextEditingController();
    // Result is ignored — the confirm button performs the delete
    // itself and pops the dialog. The Cancel button returns false
    // and just closes the dialog.
    await Get.dialog<bool>(Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delete Order',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              'The order will be hidden from active lists. An audit '
              'entry will be recorded. Cannot be undone.',
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(
                child: _ListDialogButton(
                  label:   'Delete',
                  color:   ErpColors.errorRed,
                  orderId: orderId,
                  c:       c,
                  action:  () =>
                      c.deleteOrder(orderId, reason: reasonCtrl.text.trim()),
                  // closeReturnValue is unused for delete (we don't need
                  // the bool return), but the helper still pops the
                  // dialog after the action completes.
                ),
              ),
            ]),
          ],
        ),
      ),
    ));
  }
}


// ── Shared list dialog confirm button ──────────────────────────
//   Same purpose as _DialogActionButton in order_detail_page.dart:
//   shows a spinner while the action runs, disables the button to
//   stop double-clicks, and pops the dialog AFTER the action
//   completes so the snackbar from the controller reaches the
//   underlying route. Uses OrderListController.actioningId so each
//   row's button only shows its own spinner.
class _ListDialogButton extends StatelessWidget {
  final OrderListController c;
  final String orderId;
  final String label;
  final Color color;
  final Future<void> Function() action;

  const _ListDialogButton({
    required this.c,
    required this.orderId,
    required this.label,
    required this.color,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = c.isActioningOn(orderId);
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.6),
          elevation: 0,
        ),
        onPressed: busy ? null : () async {
          await action();
          if (Get.isDialogOpen ?? false) Get.back();
        },
        child: busy
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
      );
    });
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
