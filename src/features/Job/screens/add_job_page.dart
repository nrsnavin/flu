import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/Job/controllers/add_job_controller.dart';
import 'package:production/src/features/Job/models/order_model.dart';


import '../../PurchaseOrder/services/theme.dart';

class AddJobOrderPage extends StatefulWidget {
  final OrderModel order;
  const AddJobOrderPage({super.key, required this.order});

  @override
  State<AddJobOrderPage> createState() => _AddJobOrderPageState();
}

class _AddJobOrderPageState extends State<AddJobOrderPage> {
  late final AddJobOrderController _c;

  @override
  void initState() {
    super.initState();
    Get.delete<AddJobOrderController>(force: true);
    _c = Get.put(AddJobOrderController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
    _c.initFromOrder(widget.order);
  }

  @override
  void dispose() {
    Get.delete<AddJobOrderController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Text("Create Job Order", style: ErpTextStyles.pageTitle),
            Text(
              "Order #${widget.order.orderNo}  ›  New Job",
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_c.elasticInputs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_outlined,
                            size: 48, color: ErpColors.textMuted),
                        SizedBox(height: 12),
                        Text("No elastics on this order",
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text("There is nothing to plan a job against",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: ErpColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: ErpColors.statusApprovedBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: ErpColors.statusApprovedBorder),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 16, color: ErpColors.accentBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Enter qty to allocate to this job. Up to ${kFreeExcessPct.toInt()}% over the ordered figure needs no reason. Leave blank to skip an elastic.",
                            style: TextStyle(
                                color: ErpColors.accentBlue,
                                fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Elastic cards
                    ErpSectionCard(
                      title: "ELASTIC ALLOCATION",
                      icon: Icons.layers_outlined,
                      child: Column(
                        children:
                        _c.elasticInputs.asMap().entries.map((entry) {
                          final i   = entry.key;
                          final e   = entry.value;
                          return _ElasticAllocationRow(
                              index: i, input: e);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ExcessPanel(c: _c),

                    // Order reference card
                    ErpSectionCard(
                      title: "JOB WILL CREATE",
                      icon: Icons.account_tree_outlined,
                      child: const Column(
                        children: [
                          _ProcessRow(
                              icon: Icons.grain_outlined,
                              label: "Warping Program",
                              description:
                              "Auto-created for warp yarn preparation"),
                          SizedBox(height: 8),
                          _ProcessRow(
                              icon: Icons.loop_outlined,
                              label: "Covering Program",
                              description:
                              "Auto-created for spandex covering"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          _FooterBar(c: _c),
        ],
      ),
    );
  }
}

// ── Single elastic row ──────────────────────────────────────────
class _ElasticAllocationRow extends StatelessWidget {
  final int index;
  final ElasticInput input;
  const _ElasticAllocationRow({required this.index, required this.input});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text("${index + 1}",
                style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(input.elasticName,
                    style: ErpTextStyles.cardTitle,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.pending_outlined,
                      size: 12, color: ErpColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    "${_qty(input.notAssigned)} m not assigned of ${_qty(input.ordered)} m ordered",
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
                // Live, because the figure that matters is the one being
                // typed — a total shown only after submitting is a 409.
                Obx(() {
                  if (input.excess <= 0) return const SizedBox.shrink();
                  final past = input.needsReason;
                  return Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      Icon(
                        past ? Icons.warning_amber_rounded : Icons.trending_up,
                        size: 12,
                        color: past
                            ? ErpColors.warningAmber
                            : ErpColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          past
                              ? "${_qty(input.excess)} m over (${_pct(input.excessPct)}) — needs a reason"
                              : "${_qty(input.excess)} m over (${_pct(input.excessPct)})",
                          style: TextStyle(
                            color: past
                                ? ErpColors.warningAmber
                                : ErpColors.textSecondary,
                            fontSize: 11,
                            fontWeight:
                                past ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: input.qtyController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ErpColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Qty (m)",
                labelStyle: ErpTextStyles.fieldLabel,
                filled: true,
                fillColor: ErpColors.bgSurface,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                    BorderSide(color: ErpColors.borderLight)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                    BorderSide(color: ErpColors.borderLight)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                        color: ErpColors.accentBlue, width: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _qty(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _pct(double v) {
  if (v.isInfinite) return "∞";
  return v == v.truncateToDouble()
      ? "${v.toInt()}%"
      : "${v.toStringAsFixed(1)}%";
}

// ── Excess: the warning, and the reason it may require ─────────
//
// The order's approval drew yarn for the ORDERED quantity and no more,
// so the excess is drawn here, when the job is raised. Saying that
// before the button is pressed is the difference between a decision
// and a surprise.
class _ExcessPanel extends StatelessWidget {
  final AddJobOrderController c;
  const _ExcessPanel({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.withExcess.isEmpty) return const SizedBox.shrink();
      final needsReason = c.needsReason;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: ErpColors.warningAmber.withOpacity(0.09),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ErpColors.warningAmber.withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 16, color: ErpColors.warningAmber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Planning ${_qty(c.totalExcess)} m over this order. The extra yarn is "
                    "deducted from stock when the job is created — if it is not there, "
                    "the job is refused.",
                    style: TextStyle(
                        color: ErpColors.warningAmber,
                        fontSize: 12,
                        height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          if (needsReason) ...[
            const SizedBox(height: 12),
            ErpSectionCard(
              title: "WHY MORE THAN ${kFreeExcessPct.toInt()}%?",
              icon: Icons.edit_note_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: c.reasonController,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          "e.g. loom set for a full beam; the customer takes the overrun",
                      hintStyle: TextStyle(
                          color: ErpColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: ErpColors.bgSurface,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              BorderSide(color: ErpColors.borderLight)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              BorderSide(color: ErpColors.borderLight)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                              color: ErpColors.accentBlue, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Obx(() => Text(
                        c.reasonOk
                            ? "Shown on the order, against the elastic it explains."
                            : "At least $kMinReasonLength characters. Shown on the order, "
                              "against the elastic it explains.",
                        style: TextStyle(
                          color: c.reasonOk
                              ? ErpColors.textMuted
                              : ErpColors.warningAmber,
                          fontSize: 11,
                        ),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      );
    });
  }
}

// ── Process info row ───────────────────────────────────────────
class _ProcessRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  const _ProcessRow(
      {required this.icon,
        required this.label,
        required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: ErpColors.accentBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 17, color: ErpColors.accentBlue),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ErpColors.textPrimary)),
            Text(description,
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
      Icon(Icons.auto_awesome,
          size: 14, color: ErpColors.successGreen),
    ]);
  }
}

// ── Footer ─────────────────────────────────────────────────────
class _FooterBar extends StatelessWidget {
  final AddJobOrderController c;
  const _FooterBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border(top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text("Cancel",
                  style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Obx(() => SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: c.canSubmit ? c.submitJobOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                disabledBackgroundColor:
                ErpColors.accentBlue.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: c.isSubmitting.value
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16, color: Colors.white),
              label: Text(
                c.isSubmitting.value ? "Creating…" : "Create Job",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          )),
        ),
      ]),
    );
  }
}